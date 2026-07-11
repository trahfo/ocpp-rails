# frozen_string_literal: true

require "test_helper"
require_relative "../support/ocpp_test_helper"

module Ocpp
  module Rails
    # OCTT TC_005_1 — EV Side Disconnected
    #
    # Flow: charging session -> SuspendedEV -> StopTransaction (reason
    # EVDisconnected) -> Finishing -> Available. Every assertion is driven
    # through a real handler (StatusNotificationHandler / StopTransactionHandler).
    class StopTransactionReasonTest < ActiveSupport::TestCase
      include OcppTestHelper

      setup do
        @cp = create_charge_point
        @session = create_charging_session(@cp, connector_id: 1, status: "Charging", start_meter_value: 0)
      end

      # Leg 1: the charge point reports the EV stopped drawing power.
      test "SuspendedEV status notification is acknowledged" do
        response = notify_status("SuspendedEV")

        assert_equal({}, response)
      end

      # Leg 2: StopTransaction with reason EVDisconnected is accepted and the
      # session is stopped with the reported reason recorded.
      test "StopTransaction with reason EVDisconnected is accepted and stops the session" do
        response = stop_transaction("EVDisconnected")

        assert_equal "Accepted", response.dig("idTagInfo", "status")

        @session.reload
        refute @session.active?, "session should no longer be active after StopTransaction"
        assert_equal "EVDisconnected", @session.stop_reason
      end

      # Leg 3: after the transaction stops, the connector transitions
      # Finishing -> Available as reported by the station.
      test "connector returns to Available after the transaction stops" do
        stop_transaction("EVDisconnected")

        assert_equal({}, notify_status("Finishing"))
        assert_equal({}, notify_status("Available"))

        assert_equal "Available", @cp.reload.connector_status(1)
      end

      # End-to-end TC_005_1 walkthrough exercising every leg in order.
      test "TC_005_1 end to end EV side disconnected flow" do
        # EV stops drawing power.
        assert_equal({}, notify_status("SuspendedEV"))

        # Charge point reports the transaction stopped due to EV disconnect.
        stop_response = stop_transaction("EVDisconnected")
        assert_equal "Accepted", stop_response.dig("idTagInfo", "status")

        @session.reload
        refute @session.active?
        assert_equal "EVDisconnected", @session.stop_reason

        # Connector winds down to Available.
        assert_equal({}, notify_status("Finishing"))
        assert_equal({}, notify_status("Available"))

        assert_equal "Available", @cp.reload.connector_status(1)
      end

      private

      def notify_status(status, connector_id: 1)
        Actions::StatusNotificationHandler.new(
          @cp,
          SecureRandom.uuid,
          { "connectorId" => connector_id, "status" => status, "errorCode" => "NoError" }
        ).call
      end

      def stop_transaction(reason, meter_stop: 2000)
        Actions::StopTransactionHandler.new(
          @cp,
          SecureRandom.uuid,
          {
            "transactionId" => @session.transaction_id,
            "reason" => reason,
            "meterStop" => meter_stop,
            "timestamp" => Time.current.iso8601
          }
        ).call
      end
    end
  end
end
