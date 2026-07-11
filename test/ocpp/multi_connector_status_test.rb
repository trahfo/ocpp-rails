# frozen_string_literal: true

require "test_helper"
require_relative "../support/ocpp_test_helper"

module Ocpp
  module Rails
    # A transaction on one connector must not affect the whole-station
    # status or any sibling connector's status. OCPP 1.6 keeps these
    # independent: connector status is reported per connector via
    # StatusNotification, and connector 0 (the main controller) has no
    # direct connection to any individual connector.
    class MultiConnectorStatusTest < ActiveSupport::TestCase
      include OcppTestHelper

      setup do
        @cp = create_charge_point
        notify_status(connector_id: 1, status: "Available")
        notify_status(connector_id: 2, status: "Preparing")
      end

      test "StartTransaction on one connector leaves station and sibling connector untouched" do
        response = start_transaction(connector_id: 2)

        assert_equal "Accepted", response.dig("idTagInfo", "status")

        @cp.reload
        assert_equal "Available", @cp.status,
          "whole-station status must not be driven by a connector's transaction"
        assert_equal "Available", @cp.connector_status(1),
          "sibling connector status must be unaffected"
      end

      test "connector_charging? reflects the active session on that connector only" do
        start_transaction(connector_id: 2)

        assert @cp.connector_charging?(2)
        assert_not @cp.connector_charging?(1)

        session = @cp.charging_sessions.active.find_by!(connector_id: 2)
        stop_transaction(session)

        assert_not @cp.reload.connector_charging?(2)
      end

      test "charging scope returns charge points with an active session" do
        idle = create_charge_point
        start_transaction(connector_id: 2)

        assert_includes ChargePoint.charging, @cp
        assert_not_includes ChargePoint.charging, idle
      end

      test "StopTransaction does not overwrite the station-reported status" do
        start_transaction(connector_id: 2)
        notify_status(connector_id: 0, status: "Unavailable")

        session = @cp.charging_sessions.active.find_by!(connector_id: 2)
        response = stop_transaction(session)

        assert_equal "Accepted", response.dig("idTagInfo", "status")
        assert_equal "Unavailable", @cp.reload.status,
          "whole-station status is owned by connector-0 StatusNotification, not the transaction lifecycle"
      end

      private

      def notify_status(connector_id:, status:)
        Actions::StatusNotificationHandler.new(
          @cp,
          SecureRandom.uuid,
          { "connectorId" => connector_id, "status" => status, "errorCode" => "NoError" }
        ).call
      end

      def stop_transaction(session, meter_stop: 1000)
        Actions::StopTransactionHandler.new(
          @cp,
          SecureRandom.uuid,
          {
            "transactionId" => session.transaction_id,
            "meterStop" => meter_stop,
            "timestamp" => Time.current.iso8601
          }
        ).call
      end

      def start_transaction(connector_id:, id_tag: "TAG-MULTI")
        Actions::StartTransactionHandler.new(
          @cp,
          SecureRandom.uuid,
          {
            "connectorId" => connector_id,
            "idTag" => id_tag,
            "meterStart" => 0,
            "timestamp" => Time.current.iso8601
          }
        ).call
      end
    end
  end
end
