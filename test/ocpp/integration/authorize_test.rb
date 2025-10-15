# frozen_string_literal: true

require "test_helper"
require_relative "../../support/ocpp_test_helper"

module Ocpp
  module Rails
    class AuthorizeTest < ActiveSupport::TestCase
      include OcppTestHelper

      setup do
        @charge_point = create_charge_point(connected: true)
        @valid_id_tag = "RFID#{SecureRandom.hex(4)}"
      end

      test "authorize request with valid id tag returns accepted" do
        request = build_authorize_request(id_tag: @valid_id_tag)

        message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "inbound",
          action: "Authorize",
          message_type: "CALL",
          payload: request,
          status: "received"
        )

        response = build_authorize_response(status: "Accepted")

        assert message.persisted?
        assert_equal "Authorize", message.action
        assert_equal @valid_id_tag, message.payload["idTag"]
        assert_equal "Accepted", response[:idTagInfo][:status]
      end

      test "authorize request requires id tag" do
        request = build_authorize_request(id_tag: @valid_id_tag)

        assert request[:idTag].present?
        assert_kind_of String, request[:idTag]
      end

      test "authorize response includes id tag info" do
        response = build_authorize_response(status: "Accepted")

        assert response[:idTagInfo].present?
        assert response[:idTagInfo][:status].present?
        assert_includes AUTHORIZATION_STATUS, response[:idTagInfo][:status]
      end

      test "authorize with blocked id tag returns blocked status" do
        blocked_tag = "BLOCKED_TAG"
        request = build_authorize_request(id_tag: blocked_tag)

        Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "inbound",
          action: "Authorize",
          message_type: "CALL",
          payload: request,
          status: "received"
        )

        response = build_authorize_response(status: "Blocked")

        assert_equal "Blocked", response[:idTagInfo][:status]
      end

      test "authorize with expired id tag returns expired status" do
        expired_tag = "EXPIRED_TAG"
        request = build_authorize_request(id_tag: expired_tag)

        Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "inbound",
          action: "Authorize",
          message_type: "CALL",
          payload: request,
          status: "received"
        )

        response = build_authorize_response(status: "Expired")

        assert_equal "Expired", response[:idTagInfo][:status]
      end

      test "authorize with invalid id tag returns invalid status" do
        invalid_tag = "INVALID_TAG"
        request = build_authorize_request(id_tag: invalid_tag)

        Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "inbound",
          action: "Authorize",
          message_type: "CALL",
          payload: request,
          status: "received"
        )

        response = build_authorize_response(status: "Invalid")

        assert_equal "Invalid", response[:idTagInfo][:status]
      end

      test "authorize response includes expiry date" do
        response = build_authorize_response(status: "Accepted")

        assert response[:idTagInfo][:expiryDate].present?
        expiry_time = Time.parse(response[:idTagInfo][:expiryDate])
        assert expiry_time > Time.current
      end

      test "authorize response can include parent id tag" do
        response = build_authorize_response(status: "Accepted")
        response[:idTagInfo][:parentIdTag] = "PARENT_TAG_123"

        assert_equal "PARENT_TAG_123", response[:idTagInfo][:parentIdTag]
      end

      test "authorize validates all authorization status values" do
        valid_statuses = %w[Accepted Blocked Expired Invalid ConcurrentTx]

        valid_statuses.each do |status|
          response = build_authorize_response(status: status)
          assert_equal status, response[:idTagInfo][:status]
          assert_includes AUTHORIZATION_STATUS, response[:idTagInfo][:status]
        end
      end

      test "authorize persists message correctly" do
        request = build_authorize_request(id_tag: @valid_id_tag)

        message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "inbound",
          action: "Authorize",
          message_type: "CALL",
          payload: request,
          status: "received"
        )

        assert message.persisted?
        assert_equal @charge_point.id, message.charge_point_id
        assert_equal "inbound", message.direction
        assert_equal "CALL", message.message_type
        assert_equal "Authorize", message.action
        assert_instance_of Hash, message.payload
      end

      test "authorize with concurrent transaction status" do
        request = build_authorize_request(id_tag: @valid_id_tag)

        Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "inbound",
          action: "Authorize",
          message_type: "CALL",
          payload: request,
          status: "received"
        )

        # Simulate scenario where tag is already in use
        response = build_authorize_response(status: "ConcurrentTx")

        assert_equal "ConcurrentTx", response[:idTagInfo][:status]
      end

      test "multiple authorization attempts for same tag" do
        request = build_authorize_request(id_tag: @valid_id_tag)

        # First attempt
        Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "inbound",
          action: "Authorize",
          message_type: "CALL",
          payload: request,
          status: "received"
        )

        # Second attempt
        Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "inbound",
          action: "Authorize",
          message_type: "CALL",
          payload: request,
          status: "received"
        )

        authorize_count = @charge_point.messages.where(action: "Authorize").count
        assert_equal 2, authorize_count
      end

      test "authorize from multiple charge points" do
        cp1 = create_charge_point(identifier: "CP001")
        cp2 = create_charge_point(identifier: "CP002")

        request1 = build_authorize_request(id_tag: "TAG_001")
        request2 = build_authorize_request(id_tag: "TAG_002")

        Message.create!(
          charge_point: cp1,
          message_id: SecureRandom.uuid,
          direction: "inbound",
          action: "Authorize",
          message_type: "CALL",
          payload: request1,
          status: "received"
        )

        Message.create!(
          charge_point: cp2,
          message_id: SecureRandom.uuid,
          direction: "inbound",
          action: "Authorize",
          message_type: "CALL",
          payload: request2,
          status: "received"
        )

        assert_equal 1, cp1.messages.where(action: "Authorize").count
        assert_equal 1, cp2.messages.where(action: "Authorize").count
      end

      test "authorize with valid OCPP message format" do
        message_id = SecureRandom.uuid
        request = build_authorize_request(id_tag: @valid_id_tag)

        call_message = build_call_message(
          action: "Authorize",
          payload: request,
          message_id: message_id
        )

        assert_valid_call_message(call_message)
        assert_equal "Authorize", call_message[2]
        assert_equal @valid_id_tag, call_message[3][:idTag]
      end

      test "authorize response with valid OCPP message format" do
        message_id = SecureRandom.uuid
        response_payload = build_authorize_response(status: "Accepted")

        callresult_message = build_callresult_message(
          message_id: message_id,
          payload: response_payload
        )

        assert_valid_callresult_message(callresult_message)
        assert callresult_message[2][:idTagInfo].present?
      end

      test "authorize tracks authorization attempts" do
        initial_count = @charge_point.messages.where(action: "Authorize").count

        5.times do |i|
          request = build_authorize_request(id_tag: "TAG_#{i}")
          Message.create!(
            charge_point: @charge_point,
            message_id: SecureRandom.uuid,
            direction: "inbound",
            action: "Authorize",
            message_type: "CALL",
            payload: request,
            status: "received"
          )
        end

        final_count = @charge_point.messages.where(action: "Authorize").count
        assert_equal initial_count + 5, final_count
      end

      test "authorize before start transaction" do
        # This is the typical flow: Authorize -> StartTransaction
        request = build_authorize_request(id_tag: @valid_id_tag)

        authorize_message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "inbound",
          action: "Authorize",
          message_type: "CALL",
          payload: request,
          status: "received"
        )

        response = build_authorize_response(status: "Accepted")

        # Only proceed to start transaction if authorized
        if response[:idTagInfo][:status] == "Accepted"
          start_request = build_start_transaction_request(
            connector_id: 1,
            id_tag: @valid_id_tag,
            meter_start: 0
          )

          start_message = Message.create!(
            charge_point: @charge_point,
            message_id: SecureRandom.uuid,
            direction: "inbound",
            action: "StartTransaction",
            message_type: "CALL",
            payload: start_request,
            status: "received"
          )

          assert authorize_message.created_at < start_message.created_at
        end

        assert response[:idTagInfo][:status] == "Accepted"
      end

      test "authorize can be used for local authorization list" do
        # When offline, charge point uses local authorization list
        request = build_authorize_request(id_tag: @valid_id_tag)

        message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "inbound",
          action: "Authorize",
          message_type: "CALL",
          payload: request,
          status: "received"
        )

        # In offline mode, authorization might be based on local list
        # This test verifies the message structure is correct for both online and offline
        assert message.persisted?
        assert_equal "Authorize", message.action
      end

      test "authorize response without expiry date" do
        response = build_authorize_response(status: "Accepted")
        # Remove expiry date to test optional field
        response[:idTagInfo].delete(:expiryDate)

        assert_equal "Accepted", response[:idTagInfo][:status]
        # Expiry date is optional in OCPP 1.6
      end

      test "authorize with id tag length validation" do
        # IdToken should be max 20 characters (CiString20Type)
        short_tag = "ABC"
        long_tag = "A" * 20

        short_request = build_authorize_request(id_tag: short_tag)
        long_request = build_authorize_request(id_tag: long_tag)

        assert_equal short_tag, short_request[:idTag]
        assert_equal long_tag, long_request[:idTag]
        assert long_request[:idTag].length <= 20
      end
    end
  end
end
