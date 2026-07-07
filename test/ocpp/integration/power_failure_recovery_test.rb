# frozen_string_literal: true

require "test_helper"
require_relative "../../support/ocpp_test_helper"

module Ocpp
  module Rails
    # OCTT TC_032_1: Power failure recovery mid-transaction.
    #
    # A station that loses power while charging comes back up, re-registers
    # via BootNotification, reports the recovered connector states, and stops
    # the transaction that was interrupted with reason "PowerLoss". This drives
    # the real handlers (BootNotification, StatusNotification, StopTransaction)
    # exactly as the CSMS runs them when a station reboots.
    class PowerFailureRecoveryTest < ActiveSupport::TestCase
      include OcppTestHelper

      setup do
        @cp = create_charge_point
        @session = create_charging_session(
          @cp,
          connector_id: 1,
          status: "Charging",
          start_meter_value: 0
        )
      end

      # Step 1: after power is restored the station reboots and the CSMS
      # accepts the fresh BootNotification, re-registering the charge point.
      test "reboot re-registers the charge point" do
        response = Actions::BootNotificationHandler.new(
          @cp,
          SecureRandom.uuid,
          build_boot_notification_request.stringify_keys
        ).call

        assert_equal "Accepted", response["status"]
      end

      # Step 2: the recovered station reports connector states. The interrupted
      # connector settles into "Finishing" and the idle one into "Available";
      # StatusNotification carries no payload in its response.
      test "post-reboot connector status notifications are acknowledged" do
        assert_equal({}, status_notification(connector_id: 1, status: "Finishing"))
        assert_equal({}, status_notification(connector_id: 2, status: "Available"))
      end

      # Step 3: the transaction that was live when power was lost is stopped
      # with reason "PowerLoss", and the CSMS closes the session accordingly.
      test "interrupted transaction is stopped with PowerLoss" do
        response = Actions::StopTransactionHandler.new(
          @cp,
          SecureRandom.uuid,
          {
            "transactionId" => @session.transaction_id,
            "reason" => "PowerLoss",
            "meterStop" => 500,
            "timestamp" => Time.current.iso8601
          }
        ).call

        assert_equal "Accepted", response["idTagInfo"]["status"]

        @session.reload
        refute_nil @session.stopped_at, "interrupted session should be stopped"
        assert_equal "PowerLoss", @session.stop_reason
      end

      private

      def status_notification(connector_id:, status:)
        Actions::StatusNotificationHandler.new(
          @cp,
          SecureRandom.uuid,
          {
            "connectorId" => connector_id,
            "status" => status,
            "errorCode" => "NoError",
            "timestamp" => Time.current.iso8601
          }
        ).call
      end
    end
  end
end
