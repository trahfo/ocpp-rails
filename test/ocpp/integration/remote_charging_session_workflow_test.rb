# frozen_string_literal: true

require "test_helper"
require_relative "../../support/ocpp_test_helper"

module Ocpp
  module Rails
    # End-to-end integration test for complete remote charging session workflow
    # This test demonstrates the full OCPP 1.6 message flow for remotely starting
    # and stopping a charging session with continuous meter value monitoring.
    #
    # Message Flow:
    # 1. CS → CP: RemoteStartTransaction
    # 2. CP → CS: RemoteStartTransaction.conf (Accepted)
    # 3. CP → CS: StatusNotification (Preparing)
    # 4. CP → CS: StartTransaction
    # 5. CS → CP: StartTransaction.conf (Accepted with transactionId)
    # 6. CP → CS: StatusNotification (Charging)
    # 7. CP → CS: MeterValues (periodic during charging)
    # 8. CS → CP: RemoteStopTransaction
    # 9. CP → CS: RemoteStopTransaction.conf (Accepted)
    # 10. CP → CS: StopTransaction
    # 11. CS → CP: StopTransaction.conf (Accepted)
    # 12. CP → CS: StatusNotification (Finishing)
    # 13. CP → CS: StatusNotification (Available)
    class RemoteChargingSessionWorkflowTest < ActiveSupport::TestCase
      include OcppTestHelper

      setup do
        @charge_point = create_charge_point(
          identifier: "CP_TEST_001",
          vendor: "TestVendor",
          model: "TestModel v1",
          serial_number: "SN123456",
          firmware_version: "1.0.0",
          ocpp_protocol: "1.6",
          status: "Available",
          connected: true,
          last_heartbeat_at: Time.current
        )
        @connector_id = 1
        @id_tag = "RFID_USER_001"
      end

      test "complete remote charging session workflow with meter values" do
        # Initial state verification
        assert @charge_point.connected?
        assert_equal "Available", @charge_point.status
        assert_equal 0, @charge_point.charging_sessions.active.count

        # ============================================================
        # STEP 1: Central System sends RemoteStartTransaction
        # ============================================================
        remote_start_request = build_remote_start_transaction_request(
          id_tag: @id_tag,
          connector_id: @connector_id
        )

        remote_start_message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "outbound",
          action: "RemoteStartTransaction",
          message_type: "CALL",
          payload: remote_start_request,
          status: "sent"
        )

        assert remote_start_message.persisted?
        assert_equal "RemoteStartTransaction", remote_start_message.action
        assert_equal @id_tag, remote_start_message.payload["idTag"]

        # ============================================================
        # STEP 2: Charge Point accepts RemoteStartTransaction
        # ============================================================
        remote_start_response = { status: "Accepted" }
        assert_equal "Accepted", remote_start_response[:status]

        # ============================================================
        # STEP 3: Charge Point sends StatusNotification (Preparing)
        # ============================================================
        preparing_status_request = build_status_notification_request(
          connector_id: @connector_id,
          status: "Preparing",
          error_code: "NoError"
        )

        preparing_status_message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "inbound",
          action: "StatusNotification",
          message_type: "CALL",
          payload: preparing_status_request,
          status: "received"
        )

        @charge_point.update!(status: "Preparing")
        assert_equal "Preparing", @charge_point.status

        # ============================================================
        # STEP 4: Charge Point sends StartTransaction
        # ============================================================
        start_meter_value = 1000
        start_transaction_request = build_start_transaction_request(
          connector_id: @connector_id,
          id_tag: @id_tag,
          meter_start: start_meter_value
        )

        start_transaction_message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "inbound",
          action: "StartTransaction",
          message_type: "CALL",
          payload: start_transaction_request,
          status: "received"
        )

        # Create charging session
        session = create_charging_session(
          @charge_point,
          connector_id: @connector_id,
          id_tag: @id_tag,
          status: "Preparing",
          started_at: Time.current,
          start_meter_value: start_meter_value
        )

        assert session.persisted?
        assert session.active?
        assert_equal @connector_id, session.connector_id
        assert_equal @id_tag, session.id_tag
        assert_equal start_meter_value, session.start_meter_value

        # ============================================================
        # STEP 5: Central System responds to StartTransaction
        # ============================================================
        start_transaction_response = build_start_transaction_response(
          transaction_id: session.id,
          status: "Accepted"
        )

        assert_equal "Accepted", start_transaction_response[:idTagInfo][:status]
        assert start_transaction_response[:transactionId].present?

        # ============================================================
        # STEP 6: Charge Point sends StatusNotification (Charging)
        # ============================================================
        charging_status_request = build_status_notification_request(
          connector_id: @connector_id,
          status: "Charging",
          error_code: "NoError"
        )

        charging_status_message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "inbound",
          action: "StatusNotification",
          message_type: "CALL",
          payload: charging_status_request,
          status: "received"
        )

        @charge_point.update!(status: "Charging")
        session.update!(status: "Charging")
        assert_equal "Charging", @charge_point.status
        assert_equal "Charging", session.status

        # ============================================================
        # STEP 7: Charge Point sends periodic MeterValues
        # ============================================================
        # Simulate 5 meter value readings over 5 minutes
        meter_readings = [
          { timestamp: 5.minutes.ago, energy: 3000, power: 7200 },
          { timestamp: 4.minutes.ago, energy: 5000, power: 7200 },
          { timestamp: 3.minutes.ago, energy: 7000, power: 7200 },
          { timestamp: 2.minutes.ago, energy: 9000, power: 7200 },
          { timestamp: 1.minute.ago, energy: 11000, power: 7200 }
        ]

        meter_readings.each do |reading|
          meter_values_request = build_meter_values_request(
            connector_id: @connector_id,
            transaction_id: session.transaction_id,
            meter_values: [
              build_meter_value(
                timestamp: reading[:timestamp],
                values: [
                  {
                    value: reading[:energy].to_s,
                    context: "Sample.Periodic",
                    measurand: "Energy.Active.Import.Register",
                    unit: "Wh"
                  },
                  {
                    value: reading[:power].to_s,
                    context: "Sample.Periodic",
                    measurand: "Power.Active.Import",
                    unit: "W"
                  }
                ]
              )
            ]
          )

          meter_values_message = Message.create!(
            charge_point: @charge_point,
            message_id: SecureRandom.uuid,
            direction: "inbound",
            action: "MeterValues",
            message_type: "CALL",
            payload: meter_values_request,
            status: "received"
          )

          # Store meter values in database
          create_meter_value(
            @charge_point,
            session,
            connector_id: @connector_id,
            measurand: "Energy.Active.Import.Register",
            value: reading[:energy],
            unit: "Wh",
            timestamp: reading[:timestamp],
            context: "Sample.Periodic"
          )

          create_meter_value(
            @charge_point,
            session,
            connector_id: @connector_id,
            measurand: "Power.Active.Import",
            value: reading[:power],
            unit: "W",
            timestamp: reading[:timestamp],
            context: "Sample.Periodic"
          )
        end

        # Verify meter values were recorded
        assert_equal 10, session.meter_values.count # 5 readings × 2 values each
        energy_values = session.meter_values.where(measurand: "Energy.Active.Import.Register")
        assert_equal 5, energy_values.count

        # Verify energy progression
        energy_progression = energy_values.order(timestamp: :asc).pluck(:value)
        assert_equal [3000, 5000, 7000, 9000, 11000], energy_progression

        # ============================================================
        # STEP 8: Central System sends RemoteStopTransaction
        # ============================================================
        remote_stop_request = build_remote_stop_transaction_request(
          transaction_id: session.transaction_id
        )

        remote_stop_message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "outbound",
          action: "RemoteStopTransaction",
          message_type: "CALL",
          payload: remote_stop_request,
          status: "sent"
        )

        assert remote_stop_message.persisted?
        assert_equal "RemoteStopTransaction", remote_stop_message.action
        assert_equal session.transaction_id, remote_stop_message.payload["transactionId"]

        # ============================================================
        # STEP 9: Charge Point accepts RemoteStopTransaction
        # ============================================================
        remote_stop_response = { status: "Accepted" }
        assert_equal "Accepted", remote_stop_response[:status]

        # ============================================================
        # STEP 10: Charge Point sends StopTransaction
        # ============================================================
        stop_meter_value = 13000
        stop_transaction_request = build_stop_transaction_request(
          transaction_id: session.transaction_id,
          meter_stop: stop_meter_value,
          reason: "Remote"
        )

        # Include transaction data (meter values during session)
        stop_transaction_request[:transactionData] = [
          build_meter_value(
            timestamp: 1.minute.ago,
            values: [
              {
                value: "11000",
                context: "Transaction.End",
                measurand: "Energy.Active.Import.Register",
                unit: "Wh"
              }
            ]
          )
        ]

        stop_transaction_message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "inbound",
          action: "StopTransaction",
          message_type: "CALL",
          payload: stop_transaction_request,
          status: "received"
        )

        # Stop the session
        session.stop!(meter_value: stop_meter_value, reason: "Remote")

        refute session.active?
        assert session.stopped_at.present?
        assert_equal stop_meter_value, session.stop_meter_value
        assert_equal "Remote", session.stop_reason
        assert_equal "Completed", session.status

        # Verify energy consumed calculation
        expected_energy = stop_meter_value - start_meter_value
        assert_equal expected_energy, session.energy_consumed
        assert_equal 12000, session.energy_consumed # 13000 - 1000

        # Verify duration calculation
        assert session.duration_seconds.present?
        assert session.duration_seconds >= 0

        # ============================================================
        # STEP 11: Central System responds to StopTransaction
        # ============================================================
        stop_transaction_response = build_stop_transaction_response(
          status: "Accepted"
        )

        assert_equal "Accepted", stop_transaction_response[:idTagInfo][:status]

        # ============================================================
        # STEP 12: Charge Point sends StatusNotification (Finishing)
        # ============================================================
        finishing_status_request = build_status_notification_request(
          connector_id: @connector_id,
          status: "Finishing",
          error_code: "NoError"
        )

        finishing_status_message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "inbound",
          action: "StatusNotification",
          message_type: "CALL",
          payload: finishing_status_request,
          status: "received"
        )

        @charge_point.update!(status: "Finishing")
        assert_equal "Finishing", @charge_point.status

        # ============================================================
        # STEP 13: Charge Point sends StatusNotification (Available)
        # ============================================================
        available_status_request = build_status_notification_request(
          connector_id: @connector_id,
          status: "Available",
          error_code: "NoError"
        )

        available_status_message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "inbound",
          action: "StatusNotification",
          message_type: "CALL",
          payload: available_status_request,
          status: "received"
        )

        @charge_point.update!(status: "Available")
        assert_equal "Available", @charge_point.status

        # ============================================================
        # Final Verification
        # ============================================================

        # Verify message count and types
        all_messages = @charge_point.messages.order(created_at: :asc)
        assert all_messages.count >= 8 # At least 8 main messages

        # Verify message sequence
        message_actions = all_messages.pluck(:action)
        assert_includes message_actions, "RemoteStartTransaction"
        assert_includes message_actions, "StartTransaction"
        assert_includes message_actions, "MeterValues"
        assert_includes message_actions, "RemoteStopTransaction"
        assert_includes message_actions, "StopTransaction"
        assert_includes message_actions, "StatusNotification"

        # Verify session data
        assert_equal 0, @charge_point.charging_sessions.active.count
        assert_equal 1, @charge_point.charging_sessions.completed.count

        completed_session = @charge_point.charging_sessions.completed.first
        assert_equal session.id, completed_session.id
        assert_equal 12000, completed_session.energy_consumed
        assert completed_session.duration_seconds >= 0
        assert_equal "Remote", completed_session.stop_reason

        # Verify charge point returned to available state
        assert @charge_point.connected?
        assert_equal "Available", @charge_point.status
        assert @charge_point.available?

        # Verify all meter values were stored
        assert_equal 10, session.meter_values.count
        assert session.meter_values.energy.count > 0
        assert session.meter_values.power.count > 0

        # Verify charge point can accept new sessions
        assert @charge_point.available?
        refute @charge_point.current_session.present?
      end

      test "remote charging session with multiple connectors" do
        # Test charging on connector 1
        session1 = create_charging_session(
          @charge_point,
          connector_id: 1,
          id_tag: "TAG_001",
          status: "Charging",
          started_at: Time.current,
          start_meter_value: 1000
        )

        # Test charging on connector 2 simultaneously
        session2 = create_charging_session(
          @charge_point,
          connector_id: 2,
          id_tag: "TAG_002",
          status: "Charging",
          started_at: Time.current,
          start_meter_value: 2000
        )

        assert_equal 2, @charge_point.charging_sessions.active.count

        # Add meter values for both connectors
        create_meter_value(@charge_point, session1, connector_id: 1, value: 5000)
        create_meter_value(@charge_point, session2, connector_id: 2, value: 8000)

        # Stop first session
        session1.stop!(meter_value: 10000, reason: "Remote")
        assert_equal 1, @charge_point.charging_sessions.active.count

        # Second session still active
        assert session2.active?
        refute session1.active?

        # Stop second session
        session2.stop!(meter_value: 15000, reason: "Remote")
        assert_equal 0, @charge_point.charging_sessions.active.count
        assert_equal 2, @charge_point.charging_sessions.completed.count
      end

      test "remote charging session with error during charging" do
        session = create_charging_session(
          @charge_point,
          connector_id: @connector_id,
          id_tag: @id_tag,
          status: "Charging",
          started_at: Time.current,
          start_meter_value: 1000
        )

        # Add some meter values
        create_meter_value(@charge_point, session, value: 3000)
        create_meter_value(@charge_point, session, value: 5000)

        # Simulate error during charging
        error_status_request = build_status_notification_request(
          connector_id: @connector_id,
          status: "Faulted",
          error_code: "GroundFailure"
        )

        error_message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "inbound",
          action: "StatusNotification",
          message_type: "CALL",
          payload: error_status_request,
          status: "received"
        )

        @charge_point.update!(status: "Faulted")

        # Session should be stopped due to error
        session.stop!(meter_value: 6000, reason: "PowerLoss")

        assert_equal "Faulted", @charge_point.status
        assert_equal "PowerLoss", session.stop_reason
        refute session.active?
      end

      test "remote charging session rejected when connector unavailable" do
        @charge_point.update!(status: "Unavailable")

        remote_start_request = build_remote_start_transaction_request(
          id_tag: @id_tag,
          connector_id: @connector_id
        )

        remote_start_message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "outbound",
          action: "RemoteStartTransaction",
          message_type: "CALL",
          payload: remote_start_request,
          status: "sent"
        )

        # Response should be Rejected
        response = { status: "Rejected" }
        assert_equal "Rejected", response[:status]

        # No session should be created
        assert_equal 0, @charge_point.charging_sessions.count
      end

      test "complete workflow respects message chronology" do
        messages = []

        # 1. RemoteStartTransaction
        messages << Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "outbound",
          action: "RemoteStartTransaction",
          message_type: "CALL",
          payload: build_remote_start_transaction_request(id_tag: @id_tag, connector_id: @connector_id),
          status: "sent",
          created_at: Time.current
        )

        sleep 0.01

        # 2. StartTransaction
        session = create_charging_session(@charge_point, connector_id: @connector_id, id_tag: @id_tag, start_meter_value: 1000)
        messages << Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "inbound",
          action: "StartTransaction",
          message_type: "CALL",
          payload: build_start_transaction_request(connector_id: @connector_id, id_tag: @id_tag, meter_start: 1000),
          status: "received",
          created_at: Time.current
        )

        sleep 0.01

        # 3. MeterValues
        messages << Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "inbound",
          action: "MeterValues",
          message_type: "CALL",
          payload: build_meter_values_request(connector_id: @connector_id, transaction_id: session.transaction_id),
          status: "received",
          created_at: Time.current
        )

        sleep 0.01

        # 4. RemoteStopTransaction
        messages << Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "outbound",
          action: "RemoteStopTransaction",
          message_type: "CALL",
          payload: build_remote_stop_transaction_request(transaction_id: session.transaction_id),
          status: "sent",
          created_at: Time.current
        )

        sleep 0.01

        # 5. StopTransaction
        messages << Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "inbound",
          action: "StopTransaction",
          message_type: "CALL",
          payload: build_stop_transaction_request(transaction_id: session.transaction_id, meter_stop: 10000),
          status: "received",
          created_at: Time.current
        )

        # Verify chronological order
        timestamps = messages.map(&:created_at)
        assert_equal timestamps.sort, timestamps

        # Verify action sequence
        action_sequence = messages.map(&:action)
        expected_sequence = ["RemoteStartTransaction", "StartTransaction", "MeterValues", "RemoteStopTransaction", "StopTransaction"]
        assert_equal expected_sequence, action_sequence
      end
    end
  end
end
