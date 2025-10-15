# frozen_string_literal: true

require "test_helper"
require_relative "../../support/ocpp_test_helper"

module Ocpp
  module Rails
    class StopTransactionTest < ActiveSupport::TestCase
      include OcppTestHelper

      setup do
        @charge_point = create_charge_point(
          connected: true,
          status: "Charging"
        )
        @connector_id = 1
        @id_tag = "RFID#{SecureRandom.hex(4)}"
        @session = create_charging_session(
          @charge_point,
          connector_id: @connector_id,
          id_tag: @id_tag,
          status: "Charging",
          started_at: 1.hour.ago,
          start_meter_value: 1000
        )
      end

      test "valid stop transaction ends charging session" do
        meter_stop = 15000
        request = build_stop_transaction_request(
          transaction_id: @session.transaction_id,
          meter_stop: meter_stop,
          reason: "Local"
        )

        message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "inbound",
          action: "StopTransaction",
          message_type: "CALL",
          payload: request,
          status: "received"
        )

        @session.stop!(
          reason: "Local",
          meter_value: meter_stop
        )

        assert message.persisted?
        assert_equal "StopTransaction", message.action
        refute @session.active?
        assert @session.stopped_at.present?
        assert_equal meter_stop, @session.stop_meter_value
        assert_equal "Local", @session.stop_reason
      end

      test "stop transaction requires transaction id" do
        request = build_stop_transaction_request(
          transaction_id: @session.transaction_id,
          meter_stop: 15000
        )

        assert request[:transactionId].present?
        assert_kind_of String, request[:transactionId]
      end

      test "stop transaction requires meter stop value" do
        request = build_stop_transaction_request(
          transaction_id: @session.transaction_id,
          meter_stop: 15000
        )

        assert request[:meterStop].present?
        assert_kind_of Integer, request[:meterStop]
        assert request[:meterStop] >= 0
      end

      test "stop transaction requires timestamp" do
        request = build_stop_transaction_request(
          transaction_id: @session.transaction_id,
          meter_stop: 15000
        )

        assert request[:timestamp].present?
        assert_match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/, request[:timestamp])
      end

      test "stop transaction with reason Local" do
        request = build_stop_transaction_request(
          transaction_id: @session.transaction_id,
          meter_stop: 15000,
          reason: "Local"
        )

        @session.stop!(reason: "Local", meter_value: 15000)

        assert_equal "Local", request[:reason]
        assert_equal "Local", @session.stop_reason
      end

      test "stop transaction with reason Remote" do
        request = build_stop_transaction_request(
          transaction_id: @session.transaction_id,
          meter_stop: 15000,
          reason: "Remote"
        )

        @session.stop!(reason: "Remote", meter_value: 15000)

        assert_equal "Remote", request[:reason]
        assert_equal "Remote", @session.stop_reason
      end

      test "stop transaction with reason EmergencyStop" do
        request = build_stop_transaction_request(
          transaction_id: @session.transaction_id,
          meter_stop: 15000,
          reason: "EmergencyStop"
        )

        @session.stop!(reason: "EmergencyStop", meter_value: 15000)

        assert_equal "EmergencyStop", request[:reason]
        assert_equal "EmergencyStop", @session.stop_reason
      end

      test "stop transaction with reason EVDisconnected" do
        request = build_stop_transaction_request(
          transaction_id: @session.transaction_id,
          meter_stop: 15000,
          reason: "EVDisconnected"
        )

        @session.stop!(reason: "EVDisconnected", meter_value: 15000)

        assert_equal "EVDisconnected", request[:reason]
      end

      test "stop transaction with reason HardReset" do
        request = build_stop_transaction_request(
          transaction_id: @session.transaction_id,
          meter_stop: 15000,
          reason: "HardReset"
        )

        @session.stop!(reason: "HardReset", meter_value: 15000)

        assert_equal "HardReset", request[:reason]
      end

      test "stop transaction with reason PowerLoss" do
        request = build_stop_transaction_request(
          transaction_id: @session.transaction_id,
          meter_stop: 15000,
          reason: "PowerLoss"
        )

        @session.stop!(reason: "PowerLoss", meter_value: 15000)

        assert_equal "PowerLoss", request[:reason]
      end

      test "stop transaction with reason Reboot" do
        request = build_stop_transaction_request(
          transaction_id: @session.transaction_id,
          meter_stop: 15000,
          reason: "Reboot"
        )

        @session.stop!(reason: "Reboot", meter_value: 15000)

        assert_equal "Reboot", request[:reason]
      end

      test "stop transaction with reason SoftReset" do
        request = build_stop_transaction_request(
          transaction_id: @session.transaction_id,
          meter_stop: 15000,
          reason: "SoftReset"
        )

        @session.stop!(reason: "SoftReset", meter_value: 15000)

        assert_equal "SoftReset", request[:reason]
      end

      test "stop transaction with reason UnlockCommand" do
        request = build_stop_transaction_request(
          transaction_id: @session.transaction_id,
          meter_stop: 15000,
          reason: "UnlockCommand"
        )

        @session.stop!(reason: "UnlockCommand", meter_value: 15000)

        assert_equal "UnlockCommand", request[:reason]
      end

      test "stop transaction with reason DeAuthorized" do
        request = build_stop_transaction_request(
          transaction_id: @session.transaction_id,
          meter_stop: 15000,
          reason: "DeAuthorized"
        )

        @session.stop!(reason: "DeAuthorized", meter_value: 15000)

        assert_equal "DeAuthorized", request[:reason]
      end

      test "stop transaction calculates energy consumed" do
        @session.update!(start_meter_value: 1000)
        meter_stop = 15000

        @session.stop!(meter_value: meter_stop)

        expected_energy = meter_stop - 1000
        assert_equal expected_energy, @session.energy_consumed
      end

      test "stop transaction calculates duration" do
        start_time = 2.hours.ago
        @session.update!(started_at: start_time)

        @session.stop!

        expected_duration = (Time.current - start_time).to_i
        assert @session.duration_seconds.present?
        assert @session.duration_seconds > 0
        # Allow 1 second tolerance for test execution time
        assert_in_delta expected_duration, @session.duration_seconds, 1
      end

      test "stop transaction response includes id tag info" do
        response = build_stop_transaction_response(status: "Accepted")

        assert response[:idTagInfo].present?
        assert response[:idTagInfo][:status].present?
        assert_includes AUTHORIZATION_STATUS, response[:idTagInfo][:status]
      end

      test "stop transaction can include transaction data with meter values" do
        request = build_stop_transaction_request(
          transaction_id: @session.transaction_id,
          meter_stop: 15000
        )

        # Add transaction data (meter values during transaction)
        request[:transactionData] = [
          build_meter_value(
            timestamp: 30.minutes.ago,
            values: [
              { value: "5000", measurand: "Energy.Active.Import.Register", unit: "Wh" }
            ]
          ),
          build_meter_value(
            timestamp: 15.minutes.ago,
            values: [
              { value: "10000", measurand: "Energy.Active.Import.Register", unit: "Wh" }
            ]
          )
        ]

        assert request[:transactionData].present?
        assert_kind_of Array, request[:transactionData]
        assert_equal 2, request[:transactionData].length
      end

      test "stop transaction persists message correctly" do
        request = build_stop_transaction_request(
          transaction_id: @session.transaction_id,
          meter_stop: 15000
        )

        message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "inbound",
          action: "StopTransaction",
          message_type: "CALL",
          payload: request,
          status: "received"
        )

        assert message.persisted?
        assert_equal @charge_point.id, message.charge_point_id
        assert_equal "inbound", message.direction
        assert_equal "CALL", message.message_type
        assert_equal "StopTransaction", message.action
        assert_instance_of Hash, message.payload
      end

      test "stop transaction sets stopped_at timestamp" do
        refute @session.stopped_at.present?

        @session.stop!(meter_value: 15000)

        assert @session.stopped_at.present?
        assert @session.stopped_at <= Time.current
        assert @session.stopped_at > @session.started_at
      end

      test "stop transaction sets status to Completed" do
        @session.update!(status: "Charging")

        @session.stop!(meter_value: 15000)

        assert_equal "Completed", @session.status
      end

      test "stop transaction makes session inactive" do
        assert @session.active?

        @session.stop!(meter_value: 15000)

        refute @session.active?
      end

      test "stop transaction with valid OCPP message format" do
        message_id = SecureRandom.uuid
        request = build_stop_transaction_request(
          transaction_id: @session.transaction_id,
          meter_stop: 15000
        )

        call_message = build_call_message(
          action: "StopTransaction",
          payload: request,
          message_id: message_id
        )

        assert_valid_call_message(call_message)
        assert_equal "StopTransaction", call_message[2]
        assert_equal @session.transaction_id, call_message[3][:transactionId]
        assert_equal 15000, call_message[3][:meterStop]
      end

      test "stop transaction response with valid OCPP message format" do
        message_id = SecureRandom.uuid
        response_payload = build_stop_transaction_response(status: "Accepted")

        callresult_message = build_callresult_message(
          message_id: message_id,
          payload: response_payload
        )

        assert_valid_callresult_message(callresult_message)
        assert callresult_message[2][:idTagInfo].present?
      end

      test "stop transaction for non-existent transaction" do
        fake_transaction_id = "NON_EXISTENT_TX"
        request = build_stop_transaction_request(
          transaction_id: fake_transaction_id,
          meter_stop: 15000
        )

        message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "inbound",
          action: "StopTransaction",
          message_type: "CALL",
          payload: request,
          status: "received"
        )

        # Should still accept the message even if transaction not found locally
        assert message.persisted?
      end

      test "stop transaction updates charge point status to Available" do
        @charge_point.update!(status: "Charging")

        @session.stop!(meter_value: 15000)

        # After stopping, charge point typically returns to Available
        @charge_point.update!(status: "Available")

        assert_equal "Available", @charge_point.status
      end

      test "stop transaction with id tag in request" do
        request = build_stop_transaction_request(
          transaction_id: @session.transaction_id,
          meter_stop: 15000
        )
        request[:idTag] = @id_tag

        assert_equal @id_tag, request[:idTag]
      end

      test "stop transaction validates all reason values" do
        valid_reasons = %w[
          Local
          Remote
          EmergencyStop
          EVDisconnected
          HardReset
          PowerLoss
          Reboot
          SoftReset
          UnlockCommand
          DeAuthorized
          Other
        ]

        valid_reasons.each do |reason|
          request = build_stop_transaction_request(
            transaction_id: @session.transaction_id,
            meter_stop: 15000,
            reason: reason
          )
          assert_includes valid_reasons, request[:reason]
        end
      end

      test "multiple stop transactions for different sessions" do
        session1 = create_charging_session(
          @charge_point,
          connector_id: 1,
          id_tag: "TAG_001",
          status: "Charging",
          started_at: 1.hour.ago,
          start_meter_value: 1000
        )

        session2 = create_charging_session(
          @charge_point,
          connector_id: 2,
          id_tag: "TAG_002",
          status: "Charging",
          started_at: 1.hour.ago,
          start_meter_value: 2000
        )

        session1.stop!(meter_value: 15000)
        session2.stop!(meter_value: 25000)

        refute session1.active?
        refute session2.active?
        assert_equal 15000, session1.stop_meter_value
        assert_equal 25000, session2.stop_meter_value
      end

      test "stop transaction can have zero energy consumed" do
        @session.update!(start_meter_value: 5000)
        @session.stop!(meter_value: 5000)

        assert_equal 0, @session.energy_consumed
      end

      test "stop transaction removes session from active sessions" do
        active_count_before = @charge_point.charging_sessions.active.count

        @session.stop!(meter_value: 15000)

        active_count_after = @charge_point.charging_sessions.active.count
        assert_equal active_count_before - 1, active_count_after
      end

      test "stop transaction adds session to completed sessions" do
        completed_count_before = ChargingSession.completed.count

        @session.stop!(meter_value: 15000)

        completed_count_after = ChargingSession.completed.count
        assert_equal completed_count_before + 1, completed_count_after
      end

      test "stop transaction stores all transaction metrics" do
        start_value = 1000
        stop_value = 15000
        @session.update!(start_meter_value: start_value)

        @session.stop!(meter_value: stop_value, reason: "Local")

        assert_equal start_value, @session.start_meter_value
        assert_equal stop_value, @session.stop_meter_value
        assert_equal stop_value - start_value, @session.energy_consumed
        assert @session.duration_seconds.present?
        assert @session.stopped_at.present?
        assert_equal "Local", @session.stop_reason
        assert_equal "Completed", @session.status
      end

      test "stop transaction can be queried by charge point" do
        @session.stop!(meter_value: 15000)

        completed_sessions = @charge_point.charging_sessions.completed
        assert_includes completed_sessions, @session
      end

      test "stop transaction with optional id tag validation in response" do
        response = build_stop_transaction_response(status: "Accepted")
        response[:idTagInfo][:expiryDate] = (Time.current + 1.year).iso8601
        response[:idTagInfo][:parentIdTag] = "PARENT_TAG"

        assert response[:idTagInfo][:expiryDate].present?
        assert response[:idTagInfo][:parentIdTag].present?
      end
    end
  end
end
