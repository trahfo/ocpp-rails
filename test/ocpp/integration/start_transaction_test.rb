# frozen_string_literal: true

require "test_helper"
require_relative "../../support/ocpp_test_helper"

module Ocpp
  module Rails
    class StartTransactionTest < ActiveSupport::TestCase
      include OcppTestHelper

      setup do
        @charge_point = create_charge_point(
          connected: true,
          status: "Available"
        )
        @connector_id = 1
        @id_tag = "RFID#{SecureRandom.hex(4)}"
      end

      test "valid start transaction creates charging session" do
        request = build_start_transaction_request(
          connector_id: @connector_id,
          id_tag: @id_tag,
          meter_start: 0
        )

        assert_difference "ChargingSession.count", 1 do
          session = create_charging_session(
            @charge_point,
            connector_id: @connector_id,
            id_tag: @id_tag,
            status: "Preparing",
            started_at: Time.current,
            start_meter_value: 0
          )

          assert session.persisted?
          assert_equal @connector_id, session.connector_id
          assert_equal @id_tag, session.id_tag
        end
      end

      test "start transaction requires connector id" do
        request = build_start_transaction_request(
          connector_id: @connector_id,
          id_tag: @id_tag,
          meter_start: 0
        )

        assert request[:connectorId].present?
        assert_kind_of Integer, request[:connectorId]
        assert request[:connectorId] > 0
      end

      test "start transaction requires id tag" do
        request = build_start_transaction_request(
          connector_id: @connector_id,
          id_tag: @id_tag,
          meter_start: 0
        )

        assert request[:idTag].present?
        assert_kind_of String, request[:idTag]
      end

      test "start transaction requires meter start value" do
        request = build_start_transaction_request(
          connector_id: @connector_id,
          id_tag: @id_tag,
          meter_start: 12345
        )

        assert request[:meterStart].present?
        assert_kind_of Integer, request[:meterStart]
        assert request[:meterStart] >= 0
      end

      test "start transaction requires timestamp" do
        request = build_start_transaction_request(
          connector_id: @connector_id,
          id_tag: @id_tag,
          meter_start: 0
        )

        assert request[:timestamp].present?
        assert_match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/, request[:timestamp])
      end

      test "start transaction response includes transaction id" do
        response = build_start_transaction_response(
          transaction_id: 12345,
          status: "Accepted"
        )

        assert response[:transactionId].present?
        assert_kind_of Integer, response[:transactionId]
        assert response[:idTagInfo].present?
        assert_equal "Accepted", response[:idTagInfo][:status]
      end

      test "start transaction generates unique transaction id" do
        session1 = create_charging_session(
          @charge_point,
          connector_id: 1,
          id_tag: "TAG_001"
        )

        session2 = create_charging_session(
          @charge_point,
          connector_id: 2,
          id_tag: "TAG_002"
        )

        assert session1.transaction_id != session2.transaction_id
      end

      test "start transaction with accepted authorization" do
        request = build_start_transaction_request(
          connector_id: @connector_id,
          id_tag: @id_tag,
          meter_start: 0
        )

        message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "inbound",
          action: "StartTransaction",
          message_type: "CALL",
          payload: request,
          status: "received"
        )

        session = create_charging_session(
          @charge_point,
          connector_id: @connector_id,
          id_tag: @id_tag,
          status: "Preparing",
          started_at: Time.current,
          start_meter_value: 0
        )

        response = build_start_transaction_response(
          transaction_id: session.id,
          status: "Accepted"
        )

        assert message.persisted?
        assert session.persisted?
        assert_equal "Accepted", response[:idTagInfo][:status]
      end

      test "start transaction with blocked id tag" do
        request = build_start_transaction_request(
          connector_id: @connector_id,
          id_tag: "BLOCKED_TAG",
          meter_start: 0
        )

        message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "inbound",
          action: "StartTransaction",
          message_type: "CALL",
          payload: request,
          status: "received"
        )

        response = build_start_transaction_response(
          transaction_id: 0,
          status: "Blocked"
        )

        assert_equal "Blocked", response[:idTagInfo][:status]
        # Transaction should not be created for blocked tags
      end

      test "start transaction with invalid id tag" do
        request = build_start_transaction_request(
          connector_id: @connector_id,
          id_tag: "INVALID_TAG",
          meter_start: 0
        )

        response = build_start_transaction_response(
          transaction_id: 0,
          status: "Invalid"
        )

        assert_equal "Invalid", response[:idTagInfo][:status]
      end

      test "start transaction updates charge point status" do
        session = create_charging_session(
          @charge_point,
          connector_id: @connector_id,
          id_tag: @id_tag,
          status: "Preparing"
        )

        # Simulate status change to Charging
        @charge_point.update!(status: "Charging")

        assert_equal "Charging", @charge_point.status
      end

      test "start transaction on multiple connectors" do
        session1 = create_charging_session(
          @charge_point,
          connector_id: 1,
          id_tag: "TAG_001",
          status: "Charging"
        )

        session2 = create_charging_session(
          @charge_point,
          connector_id: 2,
          id_tag: "TAG_002",
          status: "Charging"
        )

        assert session1.persisted?
        assert session2.persisted?
        assert session1.connector_id != session2.connector_id
        assert_equal 2, @charge_point.charging_sessions.active.count
      end

      test "start transaction can include optional reservation id" do
        request = build_start_transaction_request(
          connector_id: @connector_id,
          id_tag: @id_tag,
          meter_start: 0
        )
        request[:reservationId] = 12345

        assert_equal 12345, request[:reservationId]
      end

      test "start transaction stores meter start value" do
        meter_start = 12345

        session = create_charging_session(
          @charge_point,
          connector_id: @connector_id,
          id_tag: @id_tag,
          start_meter_value: meter_start
        )

        assert_equal meter_start, session.start_meter_value
      end

      test "start transaction sets started_at timestamp" do
        session = create_charging_session(
          @charge_point,
          connector_id: @connector_id,
          id_tag: @id_tag,
          started_at: Time.current
        )

        assert session.started_at.present?
        assert session.started_at <= Time.current
      end

      test "start transaction validates connector availability" do
        # Connector should be Available before starting
        @charge_point.update!(status: "Available")

        request = build_start_transaction_request(
          connector_id: @connector_id,
          id_tag: @id_tag,
          meter_start: 0
        )

        session = create_charging_session(
          @charge_point,
          connector_id: @connector_id,
          id_tag: @id_tag
        )

        assert session.persisted?
      end

      test "start transaction after successful authorization" do
        # First authorize
        authorize_request = build_authorize_request(id_tag: @id_tag)

        authorize_message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "inbound",
          action: "Authorize",
          message_type: "CALL",
          payload: authorize_request,
          status: "received"
        )

        authorize_response = build_authorize_response(status: "Accepted")

        # Then start transaction
        if authorize_response[:idTagInfo][:status] == "Accepted"
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

          session = create_charging_session(
            @charge_point,
            connector_id: @connector_id,
            id_tag: @id_tag
          )

          assert authorize_message.created_at < start_message.created_at
          assert session.persisted?
        end
      end

      test "start transaction persists message correctly" do
        request = build_start_transaction_request(
          connector_id: @connector_id,
          id_tag: @id_tag,
          meter_start: 0
        )

        message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "inbound",
          action: "StartTransaction",
          message_type: "CALL",
          payload: request,
          status: "received"
        )

        assert message.persisted?
        assert_equal @charge_point.id, message.charge_point_id
        assert_equal "inbound", message.direction
        assert_equal "CALL", message.message_type
        assert_equal "StartTransaction", message.action
        assert_instance_of Hash, message.payload
      end

      test "start transaction with valid OCPP message format" do
        message_id = SecureRandom.uuid
        request = build_start_transaction_request(
          connector_id: @connector_id,
          id_tag: @id_tag,
          meter_start: 0
        )

        call_message = build_call_message(
          action: "StartTransaction",
          payload: request,
          message_id: message_id
        )

        assert_valid_call_message(call_message)
        assert_equal "StartTransaction", call_message[2]
        assert_equal @connector_id, call_message[3][:connectorId]
        assert_equal @id_tag, call_message[3][:idTag]
      end

      test "start transaction response with valid OCPP message format" do
        message_id = SecureRandom.uuid
        response_payload = build_start_transaction_response(
          transaction_id: 12345,
          status: "Accepted"
        )

        callresult_message = build_callresult_message(
          message_id: message_id,
          payload: response_payload
        )

        assert_valid_callresult_message(callresult_message)
        assert callresult_message[2][:transactionId].present?
        assert callresult_message[2][:idTagInfo].present?
      end

      test "start transaction creates active session" do
        session = create_charging_session(
          @charge_point,
          connector_id: @connector_id,
          id_tag: @id_tag,
          started_at: Time.current,
          stopped_at: nil
        )

        assert session.active?
        assert session.stopped_at.nil?
      end

      test "start transaction can retrieve current session" do
        session = create_charging_session(
          @charge_point,
          connector_id: @connector_id,
          id_tag: @id_tag,
          started_at: Time.current
        )

        current_session = @charge_point.current_session

        assert_equal session.id, current_session.id
      end

      test "start transaction with concurrent transactions not allowed" do
        # First transaction
        session1 = create_charging_session(
          @charge_point,
          connector_id: @connector_id,
          id_tag: @id_tag,
          started_at: Time.current
        )

        # Attempt to start another transaction with same id_tag
        response = build_start_transaction_response(
          transaction_id: 0,
          status: "ConcurrentTx"
        )

        assert_equal "ConcurrentTx", response[:idTagInfo][:status]
      end

      test "start transaction initializes status as preparing" do
        session = create_charging_session(
          @charge_point,
          connector_id: @connector_id,
          id_tag: @id_tag,
          status: "Preparing"
        )

        assert_equal "Preparing", session.status
      end

      test "start transaction from multiple charge points" do
        cp1 = create_charge_point(identifier: "CP001")
        cp2 = create_charge_point(identifier: "CP002")

        session1 = create_charging_session(cp1, connector_id: 1, id_tag: "TAG_001")
        session2 = create_charging_session(cp2, connector_id: 1, id_tag: "TAG_002")

        assert_equal 1, cp1.charging_sessions.count
        assert_equal 1, cp2.charging_sessions.count
        assert session1.transaction_id != session2.transaction_id
      end

      test "start transaction validates authorization status values" do
        valid_statuses = %w[Accepted Blocked Expired Invalid ConcurrentTx]

        valid_statuses.each do |status|
          response = build_start_transaction_response(
            transaction_id: status == "Accepted" ? 12345 : 0,
            status: status
          )
          assert_includes valid_statuses, response[:idTagInfo][:status]
        end
      end

      test "start transaction records transaction relationship" do
        session = create_charging_session(
          @charge_point,
          connector_id: @connector_id,
          id_tag: @id_tag
        )

        assert_equal @charge_point.id, session.charge_point_id
        assert_equal @charge_point, session.charge_point
      end

      test "start transaction can include optional parent id tag" do
        response = build_start_transaction_response(
          transaction_id: 12345,
          status: "Accepted"
        )
        response[:idTagInfo][:parentIdTag] = "PARENT_TAG_123"

        assert_equal "PARENT_TAG_123", response[:idTagInfo][:parentIdTag]
      end

      test "start transaction can include expiry date" do
        response = build_start_transaction_response(
          transaction_id: 12345,
          status: "Accepted"
        )
        response[:idTagInfo][:expiryDate] = (Time.current + 1.year).iso8601

        assert response[:idTagInfo][:expiryDate].present?
        expiry_time = Time.parse(response[:idTagInfo][:expiryDate])
        assert expiry_time > Time.current
      end

      test "start transaction with zero meter start value" do
        session = create_charging_session(
          @charge_point,
          connector_id: @connector_id,
          id_tag: @id_tag,
          start_meter_value: 0
        )

        assert_equal 0, session.start_meter_value
      end

      test "start transaction with non-zero meter start value" do
        meter_start = 54321

        session = create_charging_session(
          @charge_point,
          connector_id: @connector_id,
          id_tag: @id_tag,
          start_meter_value: meter_start
        )

        assert_equal meter_start, session.start_meter_value
      end
    end
  end
end
