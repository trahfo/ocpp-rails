# frozen_string_literal: true

require "test_helper"
require_relative "../support/ocpp_test_helper"

module Ocpp
  module Rails
    # OCTT TC_001 - Cold Boot Charge Point.
    # Drives the real handlers (no mocking of production code) through the
    # cold boot sequence a station performs on power-up: BootNotification,
    # per-connector StatusNotification, then Heartbeat.
    class BootNotificationHandlerTest < ActiveSupport::TestCase
      include OcppTestHelper

      setup do
        @cp = create_charge_point
      end

      # TC_001 step 1: the CSMS accepts the cold boot, echoes a heartbeat
      # interval and a parseable currentTime, and persists the boot details.
      test "cold boot is accepted and updates the charge point" do
        payload = build_boot_notification_request.stringify_keys

        resp = Actions::BootNotificationHandler.new(@cp, SecureRandom.uuid, payload).call

        assert_equal "Accepted", resp["status"]
        assert_equal Ocpp::Rails.configuration.heartbeat_interval, resp["interval"]

        assert resp["currentTime"].present?, "expected a currentTime in the response"
        assert_parseable_iso8601 resp["currentTime"]

        @cp.reload
        # Builder default vendor is "Test Vendor"; model changes from the
        # created "Test Model v1" to the builder's "Test Model", proving the
        # handler wrote the boot payload through.
        assert_equal "Test Vendor", @cp.vendor
        assert_equal "Test Model", @cp.model
        assert @cp.connected, "charge point should be marked connected after boot"
      end

      # TC_001 step 2: after boot the station reports connector status.
      # Connector 0 addresses the whole charge point, connector 1 an EVSE;
      # both StatusNotifications return an empty response.
      test "per-connector status notifications after boot return empty" do
        boot!

        [ 0, 1 ].each do |connector_id|
          payload = build_status_notification_request(
            connector_id: connector_id,
            status: "Available"
          ).stringify_keys

          resp = Actions::StatusNotificationHandler.new(@cp, SecureRandom.uuid, payload).call

          assert_equal({}, resp, "connector #{connector_id} StatusNotification should return {}")
        end
      end

      # TC_001 step 3: the station keeps the link alive with a Heartbeat,
      # to which the CSMS replies with its current time.
      test "heartbeat after boot returns a parseable current time" do
        boot!

        resp = Actions::HeartbeatHandler.new(@cp, SecureRandom.uuid, {}).call

        assert resp["currentTime"].present?, "expected a currentTime in the heartbeat response"
        assert_parseable_iso8601 resp["currentTime"]
      end

      private

      # Performs a cold boot so status/heartbeat steps start from a booted
      # charge point, mirroring the OCTT sequence.
      def boot!
        Actions::BootNotificationHandler.new(
          @cp, SecureRandom.uuid, build_boot_notification_request.stringify_keys
        ).call
      end

      def assert_parseable_iso8601(value)
        Time.iso8601(value)
      rescue ArgumentError => error
        flunk("expected #{value.inspect} to be a parseable ISO8601 time, got #{error.message}")
      end
    end
  end
end
