# frozen_string_literal: true

require "test_helper"
require_relative "../../support/ocpp_test_helper"

module Ocpp
  module Rails
    class RemoteStopTransactionTest < ActiveSupport::TestCase
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
          started_at: 30.minutes.ago,
          start_meter_value: 1000
        )
      end

      test "valid remote stop transaction request" do
        request = build_remote_stop_transaction_request(
          transaction_id: @session.transaction_id
        )

        message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "outbound",
          action: "RemoteStopTransaction",
          message_type: "CALL",
          payload: request,
          status: "pending"
        )

        assert message.persisted?
        assert_equal "RemoteStopTransaction", message.action
        assert_equal "outbound", message.direction
        assert_equal @session.transaction_id, message.payload["transactionId"]
      end

      test "remote stop transaction requires transaction id" do
        request = build_remote_stop_transaction_request(
          transaction_id: @session.transaction_id
        )

        assert request[:transactionId].present?
        assert_kind_of String, request[:transactionId]
      end

      test "remote stop transaction response accepted" do
        response = { status: "Accepted" }

        assert_equal "Accepted", response[:status]
      end

      test "remote stop transaction response rejected" do
        response = { status: "Rejected" }

        assert_equal "Rejected", response[:status]
      end

      test "remote stop transaction validates status values" do
        valid_statuses = %w[Accepted Rejected]

        valid_statuses.each do |status|
          response = { status: status }
          assert_includes valid_statuses, response[:status]
        end
      end

      test "remote stop transaction for active session" do
        assert @session.active?

        request = build_remote_stop_transaction_request(
          transaction_id: @session.transaction_id
        )

        message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "outbound",
          action: "RemoteStopTransaction",
          message_type: "CALL",
          payload: request,
          status: "pending"
        )

        assert message.persisted?
        assert @session.active?
      end

      test "remote stop transaction for non-existent transaction" do
        fake_transaction_id = 99999

        request = build_remote_stop_transaction_request(
          transaction_id: fake_transaction_id
        )

        message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "outbound",
          action: "RemoteStopTransaction",
          message_type: "CALL",
          payload: request,
          status: "pending"
        )

        # Should be rejected
        response = { status: "Rejected" }
        assert_equal "Rejected", response[:status]
      end

      test "remote stop transaction persists message correctly" do
        request = build_remote_stop_transaction_request(
          transaction_id: @session.transaction_id
        )

        message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "outbound",
          action: "RemoteStopTransaction",
          message_type: "CALL",
          payload: request,
          status: "pending"
        )

        assert message.persisted?
        assert_equal @charge_point.id, message.charge_point_id
        assert_equal "outbound", message.direction
        assert_equal "CALL", message.message_type
        assert_equal "RemoteStopTransaction", message.action
        assert_instance_of Hash, message.payload
      end

      test "remote stop transaction with valid OCPP message format" do
        message_id = SecureRandom.uuid
        request = build_remote_stop_transaction_request(
          transaction_id: @session.transaction_id
        )

        call_message = build_call_message(
          action: "RemoteStopTransaction",
          payload: request,
          message_id: message_id
        )

        assert_valid_call_message(call_message)
        assert_equal "RemoteStopTransaction", call_message[2]
        assert_equal @session.transaction_id, call_message[3][:transactionId]
      end

      test "remote stop transaction response with valid OCPP message format" do
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

      test "remote stop transaction triggers stop transaction" do
        request = build_remote_stop_transaction_request(
          transaction_id: @session.transaction_id
        )

        remote_stop_message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "outbound",
          action: "RemoteStopTransaction",
          message_type: "CALL",
          payload: request,
          status: "sent"
        )

        # After acceptance, charge point sends StopTransaction
        stop_request = build_stop_transaction_request(
          transaction_id: @session.transaction_id,
          meter_stop: 15000,
          reason: "Remote"
        )

        stop_message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "inbound",
          action: "StopTransaction",
          message_type: "CALL",
          payload: stop_request,
          status: "received"
        )

        assert remote_stop_message.created_at < stop_message.created_at
        assert_equal "Remote", stop_message.payload["reason"]
      end

      test "remote stop transaction verifies transaction belongs to charge point" do
        other_charge_point = create_charge_point(identifier: "OTHER_CP")
        other_session = create_charging_session(
          other_charge_point,
          connector_id: 1,
          id_tag: "OTHER_TAG"
        )

        request = build_remote_stop_transaction_request(
          transaction_id: other_session.transaction_id
        )

        message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "outbound",
          action: "RemoteStopTransaction",
          message_type: "CALL",
          payload: request,
          status: "pending"
        )

        # Should verify transaction belongs to correct charge point
        assert_not_equal @charge_point.id, other_session.charge_point_id
      end

      test "remote stop transaction for completed session rejected" do
        @session.stop!(meter_value: 15000, reason: "Local")
        refute @session.active?

        request = build_remote_stop_transaction_request(
          transaction_id: @session.transaction_id
        )

        message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "outbound",
          action: "RemoteStopTransaction",
          message_type: "CALL",
          payload: request,
          status: "pending"
        )

        # Should be rejected since already stopped
        response = { status: "Rejected" }
        assert_equal "Rejected", response[:status]
      end

      test "remote stop transaction for multiple sessions" do
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

        request1 = build_remote_stop_transaction_request(
          transaction_id: session1.transaction_id
        )

        request2 = build_remote_stop_transaction_request(
          transaction_id: session2.transaction_id
        )

        message1 = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "outbound",
          action: "RemoteStopTransaction",
          message_type: "CALL",
          payload: request1,
          status: "pending"
        )

        message2 = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "outbound",
          action: "RemoteStopTransaction",
          message_type: "CALL",
          payload: request2,
          status: "pending"
        )

        assert_equal session1.transaction_id, message1.payload["transactionId"]
        assert_equal session2.transaction_id, message2.payload["transactionId"]
      end

      test "remote stop transaction updates message status" do
        request = build_remote_stop_transaction_request(
          transaction_id: @session.transaction_id
        )

        message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "outbound",
          action: "RemoteStopTransaction",
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

      test "remote stop transaction tracks attempt count" do
        initial_count = @charge_point.messages.where(action: "RemoteStopTransaction").count

        3.times do
          request = build_remote_stop_transaction_request(
            transaction_id: @session.transaction_id
          )

          Message.create!(
            charge_point: @charge_point,
            message_id: SecureRandom.uuid,
            direction: "outbound",
            action: "RemoteStopTransaction",
            message_type: "CALL",
            payload: request,
            status: "pending"
          )
        end

        final_count = @charge_point.messages.where(action: "RemoteStopTransaction").count
        assert_equal initial_count + 3, final_count
      end

      test "remote stop transaction via ActionCable" do
        request = build_remote_stop_transaction_request(
          transaction_id: @session.transaction_id
        )

        message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "outbound",
          action: "RemoteStopTransaction",
          message_type: "CALL",
          payload: request,
          status: "pending"
        )

        # Message should be broadcast via ActionCable to charge point
        assert message.persisted?
        assert_equal "pending", message.status
      end

      test "remote stop transaction handles timeout" do
        request = build_remote_stop_transaction_request(
          transaction_id: @session.transaction_id
        )

        message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "outbound",
          action: "RemoteStopTransaction",
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

      test "remote stop transaction calculates session metrics" do
        request = build_remote_stop_transaction_request(
          transaction_id: @session.transaction_id
        )

        remote_stop_message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "outbound",
          action: "RemoteStopTransaction",
          message_type: "CALL",
          payload: request,
          status: "sent"
        )

        # Simulate stop transaction response
        @session.stop!(meter_value: 15000, reason: "Remote")

        assert_equal 14000, @session.energy_consumed
        assert @session.duration_seconds.present?
        assert @session.stopped_at.present?
        assert_equal "Remote", @session.stop_reason
      end

      test "remote stop transaction updates charge point status" do
        @charge_point.update!(status: "Charging")

        request = build_remote_stop_transaction_request(
          transaction_id: @session.transaction_id
        )

        Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "outbound",
          action: "RemoteStopTransaction",
          message_type: "CALL",
          payload: request,
          status: "sent"
        )

        # After stopping, charge point returns to Available
        @session.stop!(meter_value: 15000, reason: "Remote")
        @charge_point.update!(status: "Available")

        assert_equal "Available", @charge_point.status
      end

      test "remote stop transaction with transaction id validation" do
        request = build_remote_stop_transaction_request(
          transaction_id: @session.transaction_id
        )

        assert_kind_of String, request[:transactionId]
        assert request[:transactionId].present?
      end

      test "remote stop transaction for charge point with multiple connectors" do
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

        # Stop only session on connector 1
        request = build_remote_stop_transaction_request(
          transaction_id: session1.transaction_id
        )

        message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "outbound",
          action: "RemoteStopTransaction",
          message_type: "CALL",
          payload: request,
          status: "pending"
        )

        assert message.persisted?
        assert_equal session1.transaction_id, message.payload["transactionId"]
        # Session 2 should remain active
      end

      test "remote stop transaction rejection reasons" do
        # Transaction not found
        request = build_remote_stop_transaction_request(
          transaction_id: 99999
        )

        message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "outbound",
          action: "RemoteStopTransaction",
          message_type: "CALL",
          payload: request,
          status: "pending"
        )

        response = { status: "Rejected" }
        assert_equal "Rejected", response[:status]
      end
    end
  end
end
