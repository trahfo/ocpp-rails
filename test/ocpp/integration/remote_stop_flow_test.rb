# frozen_string_literal: true

require "test_helper"
require_relative "../../support/ocpp_test_helper"

module Ocpp
  module Rails
    # OCTT TC_012: Remote Stop Charging Session.
    #
    # Drives the real outbound job (RemoteStopTransactionJob) and the inbound
    # handlers (StopTransactionHandler, StatusNotificationHandler) end-to-end,
    # exactly as the CSMS runs them in production.
    class RemoteStopFlowTest < ActiveSupport::TestCase
      include ActionCable::TestHelper
      include OcppTestHelper

      setup { @cp = create_charge_point }

      # TC_012 step 1: CSMS sends RemoteStopTransaction, the station replies with
      # a StopTransaction, and the session is closed out with the remote reason.
      test "remote stop is delivered as a CALL and the follow-up StopTransaction closes the session" do
        session = create_charging_session(@cp, connector_id: 1, status: "Charging", start_meter_value: 0)

        RemoteStopTransactionJob.perform_now(@cp.id, session.transaction_id)

        message = Message.find_by!(charge_point: @cp, action: "RemoteStopTransaction")
        assert_equal "pending", message.status,
          "outbound RemoteStopTransaction should be recorded as a pending Message"

        expected_frame = [ 2, message.message_id, "RemoteStopTransaction", { "transactionId" => session.transaction_id } ]
        assert_equal expected_frame, last_station_frame,
          "the CALL frame broadcast to the station must carry the wire transaction id"

        result = drive_stop_transaction(
          "transactionId" => session.transaction_id,
          "reason" => "Remote",
          "meterStop" => 1500,
          "timestamp" => Time.current.iso8601
        )

        assert_equal "Accepted", result["idTagInfo"]["status"]

        session.reload
        assert_not session.active?, "session should no longer be active after StopTransaction"
        assert_not_nil session.stopped_at, "stopped_at should be stamped when the session is closed"
        assert_equal "Remote", session.stop_reason
      end

      # TC_012 step 2: once the transaction is stopped, the connector cycles
      # back to Available as reported by the station's StatusNotifications.
      # Whole-station status is owned by connector-0 notifications and is not
      # part of the transaction lifecycle.
      test "connector returns to Available after the remote stop" do
        session = create_charging_session(@cp, connector_id: 1, status: "Charging", start_meter_value: 0)

        drive_stop_transaction(
          "transactionId" => session.transaction_id,
          "reason" => "Remote",
          "meterStop" => 1500,
          "timestamp" => Time.current.iso8601
        )

        assert_not @cp.connector_charging?(1),
          "no transaction should remain on the connector after StopTransaction"

        assert_equal({}, drive_status_notification(1, "Finishing"))
        assert_equal({}, drive_status_notification(1, "Available"))

        assert_equal "Available", @cp.reload.connector_status(1),
          "connector-scoped StatusNotification should record the connector status"
      end

      private

      def last_station_frame
        entries = broadcasts(ChargePointChannel.broadcasting_for(@cp))
        assert entries.any?, "nothing was broadcast on the station's stream"
        JSON.parse(JSON.parse(entries.last)["message"])
      end

      def drive_stop_transaction(payload)
        Actions::StopTransactionHandler.new(@cp, SecureRandom.uuid, payload).call
      end

      def drive_status_notification(connector_id, status)
        payload = {
          "connectorId" => connector_id,
          "status" => status,
          "errorCode" => "NoError",
          "timestamp" => Time.current.iso8601
        }
        Actions::StatusNotificationHandler.new(@cp, SecureRandom.uuid, payload).call
      end
    end
  end
end
