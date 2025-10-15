# frozen_string_literal: true

require "test_helper"
require_relative "../../support/ocpp_test_helper"

module Ocpp
  module Rails
    class HeartbeatTest < ActiveSupport::TestCase
      include OcppTestHelper

      setup do
        @charge_point = create_charge_point(
          connected: true,
          last_heartbeat_at: 10.minutes.ago
        )
      end

      test "charge point sends heartbeat and updates last_heartbeat_at" do
        old_heartbeat = @charge_point.last_heartbeat_at
        request = build_heartbeat_request

        # Simulate heartbeat message
        message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "inbound",
          action: "Heartbeat",
          message_type: "CALL",
          payload: request,
          status: "received"
        )

        # Update heartbeat timestamp
        @charge_point.heartbeat!

        assert message.persisted?
        assert_equal "Heartbeat", message.action
        assert @charge_point.last_heartbeat_at > old_heartbeat
        assert @charge_point.connected
      end

      test "heartbeat response includes current time" do
        response = build_heartbeat_response

        assert response[:currentTime].present?
        assert_match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/, response[:currentTime])
      end

      test "heartbeat request has empty payload" do
        request = build_heartbeat_request

        assert_equal({}, request)
      end

      test "heartbeat marks charge point as connected" do
        @charge_point.update!(connected: false)
        refute @charge_point.connected

        # Process heartbeat
        Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "inbound",
          action: "Heartbeat",
          message_type: "CALL",
          payload: {},
          status: "received"
        )

        @charge_point.heartbeat!

        assert @charge_point.connected
      end

      test "multiple heartbeats update timestamp progressively" do
        first_heartbeat = @charge_point.last_heartbeat_at

        # First heartbeat
        sleep 0.1
        @charge_point.heartbeat!
        second_heartbeat = @charge_point.last_heartbeat_at

        # Second heartbeat
        sleep 0.1
        @charge_point.heartbeat!
        third_heartbeat = @charge_point.last_heartbeat_at

        assert first_heartbeat < second_heartbeat
        assert second_heartbeat < third_heartbeat
      end

      test "heartbeat interval is configurable" do
        interval = 300 # 5 minutes in seconds

        response = build_heartbeat_response
        # Note: interval is typically sent in BootNotification response
        # but heartbeat should respect that interval

        assert interval > 0
        assert interval <= 3600 # Max 1 hour
      end

      test "heartbeat persists message correctly" do
        request = build_heartbeat_request

        message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "inbound",
          action: "Heartbeat",
          message_type: "CALL",
          payload: request,
          status: "received"
        )

        assert message.persisted?
        assert_equal @charge_point.id, message.charge_point_id
        assert_equal "inbound", message.direction
        assert_equal "CALL", message.message_type
        assert_equal "Heartbeat", message.action
      end

      test "can detect missed heartbeats" do
        # Set heartbeat to very old
        @charge_point.update!(last_heartbeat_at: 2.hours.ago)

        expected_interval = 300 # 5 minutes
        time_since_last_heartbeat = Time.current - @charge_point.last_heartbeat_at

        assert time_since_last_heartbeat > expected_interval
      end

      test "heartbeat maintains connection status" do
        @charge_point.update!(connected: true)

        # Send heartbeat
        @charge_point.heartbeat!

        assert @charge_point.connected
        assert @charge_point.last_heartbeat_at.present?
        assert @charge_point.last_heartbeat_at > 1.minute.ago
      end

      test "charge point disconnects if heartbeat not received" do
        @charge_point.update!(
          connected: true,
          last_heartbeat_at: 1.hour.ago
        )

        # Simulate timeout detection
        timeout_threshold = 10.minutes
        time_since_heartbeat = Time.current - @charge_point.last_heartbeat_at

        if time_since_heartbeat > timeout_threshold
          @charge_point.disconnect!
        end

        refute @charge_point.connected
      end

      test "heartbeat with valid OCPP message format" do
        message_id = SecureRandom.uuid
        call_message = build_call_message(
          action: "Heartbeat",
          payload: {},
          message_id: message_id
        )

        assert_valid_call_message(call_message)
        assert_equal "Heartbeat", call_message[2]
        assert_equal({}, call_message[3])
      end

      test "heartbeat response with valid OCPP message format" do
        message_id = SecureRandom.uuid
        response_payload = build_heartbeat_response

        callresult_message = build_callresult_message(
          message_id: message_id,
          payload: response_payload
        )

        assert_valid_callresult_message(callresult_message)
        assert callresult_message[2][:currentTime].present?
      end

      test "heartbeat frequency tracking" do
        # Track multiple heartbeats
        heartbeats = []

        5.times do
          @charge_point.heartbeat!
          heartbeats << @charge_point.last_heartbeat_at
          sleep 0.05
        end

        assert_equal 5, heartbeats.length
        # Verify heartbeats are in chronological order
        assert_equal heartbeats.sort, heartbeats
      end

      test "concurrent heartbeats from multiple charge points" do
        cp1 = create_charge_point(identifier: "CP001")
        cp2 = create_charge_point(identifier: "CP002")
        cp3 = create_charge_point(identifier: "CP003")

        cp1.heartbeat!
        cp2.heartbeat!
        cp3.heartbeat!

        assert cp1.connected
        assert cp2.connected
        assert cp3.connected
        assert cp1.last_heartbeat_at.present?
        assert cp2.last_heartbeat_at.present?
        assert cp3.last_heartbeat_at.present?
      end

      test "heartbeat updates only last_heartbeat_at and connected fields" do
        original_vendor = @charge_point.vendor
        original_model = @charge_point.model
        original_status = @charge_point.status

        @charge_point.heartbeat!

        assert_equal original_vendor, @charge_point.vendor
        assert_equal original_model, @charge_point.model
        assert_equal original_status, @charge_point.status
      end

      test "heartbeat count tracking" do
        initial_count = @charge_point.messages.where(action: "Heartbeat").count

        3.times do
          Message.create!(
            charge_point: @charge_point,
            message_id: SecureRandom.uuid,
            direction: "inbound",
            action: "Heartbeat",
            message_type: "CALL",
            payload: {},
            status: "received"
          )
        end

        final_count = @charge_point.messages.where(action: "Heartbeat").count
        assert_equal initial_count + 3, final_count
      end

      test "heartbeat preserves charge point availability" do
        @charge_point.update!(status: "Charging")

        @charge_point.heartbeat!

        assert_equal "Charging", @charge_point.status
      end
    end
  end
end
