# frozen_string_literal: true

require "test_helper"
require_relative "../support/ocpp_test_helper"

module Ocpp
  module Rails
    class StatusNotificationHandlerTest < ActiveSupport::TestCase
      include OcppTestHelper

      setup { @cp = create_charge_point }

      # TC_003: A "Preparing" status notification is acknowledged and stored.
      test "TC_003 Preparing status is acknowledged and stored" do
        response = status_notification(connector_id: 1, status: "Preparing")

        assert_equal({}, response)
        assert_equal "Preparing", @cp.reload.connector_status(1)
      end

      # TC_003: A "Charging" status notification is acknowledged and stored.
      test "TC_003 Charging status is acknowledged and stored" do
        status_notification(connector_id: 1, status: "Preparing")
        response = status_notification(connector_id: 1, status: "Charging")

        assert_equal({}, response)
        assert_equal "Charging", @cp.reload.connector_status(1)
      end

      # TC_004_1 / TC_004_2: Connector reverting to "Available" is acknowledged and recorded.
      test "TC_004 connector reverting to Available is acknowledged and recorded" do
        preparing = status_notification(connector_id: 1, status: "Preparing")
        available = status_notification(connector_id: 1, status: "Available")

        assert_equal({}, preparing)
        assert_equal({}, available)
        assert_equal "Available", @cp.reload.connector_status(1)
      end

      # TC_004_1 / TC_004_2: A StateChange row is recorded only on an actual transition.
      test "TC_004 StateChange is logged on transition but not when status repeats" do
        assert_difference "Ocpp::Rails::StateChange.count", 1 do
          status_notification(connector_id: 1, status: "Preparing")
        end

        assert_no_difference "Ocpp::Rails::StateChange.count" do
          status_notification(connector_id: 1, status: "Preparing")
        end
      end

      # connectorId 0 targets the whole charge point.
      test "connectorId 0 updates the charge point status" do
        response = status_notification(connector_id: 0, status: "Unavailable")

        assert_equal({}, response)
        assert_equal "Unavailable", @cp.reload.status
      end

      # OCPP 1.6: connector 0's status has no direct connection to the
      # status of individual connectors, and vice versa.
      test "connector-scoped notification leaves charge point status and metadata untouched" do
        status_notification(connector_id: 1, status: "Charging")

        @cp.reload
        assert_equal "Available", @cp.status
        assert_not @cp.metadata.key?("connector_1_status")
      end

      test "connectorId 0 does not create a connector status record" do
        status_notification(connector_id: 0, status: "Faulted")

        assert_nil @cp.reload.connector_status(0)
      end

      # TC_024: Connector lock failure (Faulted + ConnectorLockFailure) is stored and acknowledged.
      test "TC_024 connector lock failure is stored and acknowledged" do
        response = status_notification(
          connector_id: 1,
          status: "Faulted",
          error_code: "ConnectorLockFailure"
        )

        assert_equal({}, response)

        @cp.reload
        assert_equal "Faulted", @cp.connector_status(1)
        assert_equal "ConnectorLockFailure", @cp.connector_error_code(1)

        state_change = @cp.state_changes.status_changes.where(new_value: "Faulted").last
        assert_not_nil state_change, "expected a StateChange row for the Faulted transition"
        assert_equal 1, state_change.connector_id
        assert_equal "ConnectorLockFailure", state_change.metadata["error_code"]
      end

      private

      def status_notification(connector_id:, status:, error_code: "NoError")
        Actions::StatusNotificationHandler.new(
          @cp,
          SecureRandom.uuid,
          { "connectorId" => connector_id, "status" => status, "errorCode" => error_code }
        ).call
      end
    end
  end
end
