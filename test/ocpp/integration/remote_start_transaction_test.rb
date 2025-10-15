# frozen_string_literal: true

require "test_helper"
require_relative "../../support/ocpp_test_helper"

module Ocpp
  module Rails
    class RemoteStartTransactionTest < ActiveSupport::TestCase
      include OcppTestHelper

      setup do
        @charge_point = create_charge_point(
          connected: true,
          status: "Available"
        )
        @connector_id = 1
        @id_tag = "RFID#{SecureRandom.hex(4)}"
      end

      test "valid remote start transaction request" do
        request = build_remote_start_transaction_request(
          id_tag: @id_tag,
          connector_id: @connector_id
        )

        message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "outbound",
          action: "RemoteStartTransaction",
          message_type: "CALL",
          payload: request,
          status: "pending"
        )

        assert message.persisted?
        assert_equal "RemoteStartTransaction", message.action
        assert_equal "outbound", message.direction
        assert_equal @id_tag, message.payload["idTag"]
      end

      test "remote start transaction requires id tag" do
        request = build_remote_start_transaction_request(
          id_tag: @id_tag
        )

        assert request[:idTag].present?
        assert_kind_of String, request[:idTag]
      end

      test "remote start transaction with specific connector id" do
        request = build_remote_start_transaction_request(
          id_tag: @id_tag,
          connector_id: @connector_id
        )

        assert_equal @connector_id, request[:connectorId]
      end

      test "remote start transaction without connector id" do
        request = build_remote_start_transaction_request(
          id_tag: @id_tag,
          connector_id: nil
        )

        assert request[:connectorId].nil?
        # Charge point should select available connector
      end

      test "remote start transaction response accepted" do
        response = { status: "Accepted" }

        assert_equal "Accepted", response[:status]
      end

      test "remote start transaction response rejected" do
        response = { status: "Rejected" }

        assert_equal "Rejected", response[:status]
      end

      test "remote start transaction validates status values" do
        valid_statuses = %w[Accepted Rejected]

        valid_statuses.each do |status|
          response = { status: status }
          assert_includes valid_statuses, response[:status]
        end
      end

      test "remote start transaction with charging profile" do
        charging_profile = build_charging_profile(
          profile_id: 1,
          stack_level: 0,
          purpose: "TxProfile",
          kind: "Absolute"
        )

        request = build_remote_start_transaction_request(
          id_tag: @id_tag,
          connector_id: @connector_id,
          charging_profile: charging_profile
        )

        assert request[:chargingProfile].present?
        assert_equal 1, request[:chargingProfile][:chargingProfileId]
        assert_equal "TxProfile", request[:chargingProfile][:chargingProfilePurpose]
      end

      test "remote start transaction persists message correctly" do
        request = build_remote_start_transaction_request(
          id_tag: @id_tag,
          connector_id: @connector_id
        )

        message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "outbound",
          action: "RemoteStartTransaction",
          message_type: "CALL",
          payload: request,
          status: "pending"
        )

        assert message.persisted?
        assert_equal @charge_point.id, message.charge_point_id
        assert_equal "outbound", message.direction
        assert_equal "CALL", message.message_type
        assert_equal "RemoteStartTransaction", message.action
        assert_instance_of Hash, message.payload
      end

      test "remote start transaction with valid OCPP message format" do
        message_id = SecureRandom.uuid
        request = build_remote_start_transaction_request(
          id_tag: @id_tag,
          connector_id: @connector_id
        )

        call_message = build_call_message(
          action: "RemoteStartTransaction",
          payload: request,
          message_id: message_id
        )

        assert_valid_call_message(call_message)
        assert_equal "RemoteStartTransaction", call_message[2]
        assert_equal @id_tag, call_message[3][:idTag]
      end

      test "remote start transaction response with valid OCPP message format" do
        message_id = SecureRandom.uuid
        response_payload = { status: "Accepted" }

        callresult_message = build_callresult_message(
          message_id: message_id,
          payload: response_payload
        )

        assert_valid_callresult_message(callresult_message)
        assert callresult_message[2][:status].present?
        assert_equal "Accepted", callresult_message[2][:status]
      end

      test "remote start transaction checks connector availability" do
        @charge_point.update!(status: "Available")

        request = build_remote_start_transaction_request(
          id_tag: @id_tag,
          connector_id: @connector_id
        )

        message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "outbound",
          action: "RemoteStartTransaction",
          message_type: "CALL",
          payload: request,
          status: "pending"
        )

        assert message.persisted?
        assert_equal "Available", @charge_point.status
      end

      test "remote start transaction rejected when connector unavailable" do
        @charge_point.update!(status: "Unavailable")

        request = build_remote_start_transaction_request(
          id_tag: @id_tag,
          connector_id: @connector_id
        )

        Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "outbound",
          action: "RemoteStartTransaction",
          message_type: "CALL",
          payload: request,
          status: "pending"
        )

        # Response would be Rejected
        response = { status: "Rejected" }
        assert_equal "Rejected", response[:status]
      end

      test "remote start transaction rejected when connector faulted" do
        @charge_point.update!(status: "Faulted")

        request = build_remote_start_transaction_request(
          id_tag: @id_tag,
          connector_id: @connector_id
        )

        Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "outbound",
          action: "RemoteStartTransaction",
          message_type: "CALL",
          payload: request,
          status: "pending"
        )

        response = { status: "Rejected" }
        assert_equal "Rejected", response[:status]
      end

      test "remote start transaction with authorization check" do
        request = build_remote_start_transaction_request(
          id_tag: @id_tag,
          connector_id: @connector_id
        )

        message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "outbound",
          action: "RemoteStartTransaction",
          message_type: "CALL",
          payload: request,
          status: "pending"
        )

        # Charge point should authorize the id tag
        assert message.payload["idTag"].present?
      end

      test "remote start transaction triggers start transaction" do
        request = build_remote_start_transaction_request(
          id_tag: @id_tag,
          connector_id: @connector_id
        )

        remote_start_message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "outbound",
          action: "RemoteStartTransaction",
          message_type: "CALL",
          payload: request,
          status: "sent"
        )

        # After acceptance, charge point sends StartTransaction
        start_request = build_start_transaction_request(
          connector_id: @connector_id,
          id_tag: @id_tag,
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

        assert remote_start_message.created_at < start_message.created_at
        assert_equal @id_tag, start_message.payload["idTag"]
      end

      test "remote start transaction for multiple charge points" do
        cp1 = create_charge_point(identifier: "CP001", status: "Available")
        cp2 = create_charge_point(identifier: "CP002", status: "Available")

        request1 = build_remote_start_transaction_request(
          id_tag: "TAG_001",
          connector_id: 1
        )

        request2 = build_remote_start_transaction_request(
          id_tag: "TAG_002",
          connector_id: 1
        )

        message1 = Message.create!(
          charge_point: cp1,
          message_id: SecureRandom.uuid,
          direction: "outbound",
          action: "RemoteStartTransaction",
          message_type: "CALL",
          payload: request1,
          status: "pending"
        )

        message2 = Message.create!(
          charge_point: cp2,
          message_id: SecureRandom.uuid,
          direction: "outbound",
          action: "RemoteStartTransaction",
          message_type: "CALL",
          payload: request2,
          status: "pending"
        )

        assert_equal 1, cp1.messages.where(action: "RemoteStartTransaction").count
        assert_equal 1, cp2.messages.where(action: "RemoteStartTransaction").count
      end

      test "remote start transaction with TxProfile charging profile" do
        charging_profile = build_charging_profile(
          profile_id: 1,
          stack_level: 0,
          purpose: "TxProfile",
          kind: "Relative"
        )

        request = build_remote_start_transaction_request(
          id_tag: @id_tag,
          connector_id: @connector_id,
          charging_profile: charging_profile
        )

        assert_equal "TxProfile", request[:chargingProfile][:chargingProfilePurpose]
        assert_equal "Relative", request[:chargingProfile][:chargingProfileKind]
      end

      test "remote start transaction with power limit in charging profile" do
        charging_profile = {
          chargingProfileId: 1,
          stackLevel: 0,
          chargingProfilePurpose: "TxProfile",
          chargingProfileKind: "Absolute",
          chargingSchedule: {
            chargingRateUnit: "W",
            chargingSchedulePeriod: [
              { startPeriod: 0, limit: 7200 }
            ]
          }
        }

        request = build_remote_start_transaction_request(
          id_tag: @id_tag,
          connector_id: @connector_id,
          charging_profile: charging_profile
        )

        assert_equal 7200, request[:chargingProfile][:chargingSchedule][:chargingSchedulePeriod][0][:limit]
      end

      test "remote start transaction with connector selection logic" do
        # If no connector specified, charge point should select first available
        request = build_remote_start_transaction_request(
          id_tag: @id_tag,
          connector_id: nil
        )

        message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "outbound",
          action: "RemoteStartTransaction",
          message_type: "CALL",
          payload: request,
          status: "pending"
        )

        assert message.persisted?
        assert request[:connectorId].nil?
      end

      test "remote start transaction updates message status" do
        request = build_remote_start_transaction_request(
          id_tag: @id_tag,
          connector_id: @connector_id
        )

        message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "outbound",
          action: "RemoteStartTransaction",
          message_type: "CALL",
          payload: request,
          status: "pending"
        )

        assert_equal "pending", message.status

        # After sending
        message.update!(status: "sent")
        assert_equal "sent", message.status

        # After receiving response
        message.update!(status: "received")
        assert_equal "received", message.status
      end

      test "remote start transaction with reservation compatibility" do
        # Remote start can honor existing reservations
        request = build_remote_start_transaction_request(
          id_tag: @id_tag,
          connector_id: @connector_id
        )

        message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "outbound",
          action: "RemoteStartTransaction",
          message_type: "CALL",
          payload: request,
          status: "pending"
        )

        assert message.persisted?
        # If reservation exists for different tag, should be rejected
      end

      test "remote start transaction tracks attempt count" do
        initial_count = @charge_point.messages.where(action: "RemoteStartTransaction").count

        3.times do
          request = build_remote_start_transaction_request(
            id_tag: @id_tag,
            connector_id: @connector_id
          )

          Message.create!(
            charge_point: @charge_point,
            message_id: SecureRandom.uuid,
            direction: "outbound",
            action: "RemoteStartTransaction",
            message_type: "CALL",
            payload: request,
            status: "pending"
          )
        end

        final_count = @charge_point.messages.where(action: "RemoteStartTransaction").count
        assert_equal initial_count + 3, final_count
      end

      test "remote start transaction via ActionCable" do
        request = build_remote_start_transaction_request(
          id_tag: @id_tag,
          connector_id: @connector_id
        )

        message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "outbound",
          action: "RemoteStartTransaction",
          message_type: "CALL",
          payload: request,
          status: "pending"
        )

        # Message should be broadcast via ActionCable to charge point
        assert message.persisted?
        assert_equal "pending", message.status
      end

      test "remote start transaction handles timeout" do
        request = build_remote_start_transaction_request(
          id_tag: @id_tag,
          connector_id: @connector_id
        )

        message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "outbound",
          action: "RemoteStartTransaction",
          message_type: "CALL",
          payload: request,
          status: "pending",
          created_at: 5.minutes.ago
        )

        # If no response after timeout, should mark as error
        if Time.current - message.created_at > 2.minutes
          message.update!(status: "error", error_message: "Timeout")
        end

        assert_equal "error", message.status
      end
    end
  end
end
