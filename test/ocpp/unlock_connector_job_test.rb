# frozen_string_literal: true

require "test_helper"
require_relative "../support/ocpp_test_helper"

module Ocpp
  module Rails
    # UnlockConnector remote command (OCTT TC_017_1/TC_017_2 with no session,
    # TC_018_1 releasing a plug during an active charging session). The CSMS
    # must be able to instruct a station to physically release a connector's
    # cable lock, including while a transaction is in progress, so a driver is
    # never trapped with a locked-in cable.
    class UnlockConnectorJobTest < ActiveSupport::TestCase
      include ActionCable::TestHelper
      include OcppTestHelper

      setup do
        @cp = create_charge_point
      end

      # TC_017_1: the CSMS sends UnlockConnector and it must reach the station
      # on the exact stream its WebSocket subscribes to, as a CALL frame.
      test "TC_017_1 delivers the UnlockConnector CALL frame on the station's stream" do
        UnlockConnectorJob.perform_now(@cp.id, 1)

        frame = last_frame_on_station_stream
        message = Message.find_by!(charge_point: @cp, action: "UnlockConnector")

        assert_equal 2, frame[0], "expected a CALL frame"
        assert_equal message.message_id, frame[1]
        assert_equal "UnlockConnector", frame[2]
        assert_equal({ "connectorId" => 1 }, frame[3])
        assert_equal "pending", message.status
      end

      # TC_017_2: a station that successfully unlocks answers Unlocked; the
      # pending outbound Message is reconciled to received with the response.
      test "TC_017_2 reconciles an Unlocked confirmation" do
        UnlockConnectorJob.perform_now(@cp.id, 1)

        message = feed_unlock_confirmation("Unlocked")

        assert_equal "received", message.status
        assert_equal "Unlocked", message.payload.dig("response", "status")
      end

      # TC_017_2: a fixed-cable connector cannot be unlocked and answers
      # NotSupported. This is a valid confirmation, not an error, and must be
      # reconciled cleanly without raising.
      test "TC_017_2 reconciles a NotSupported confirmation for a fixed cable" do
        UnlockConnectorJob.perform_now(@cp.id, 1)

        message = nil
        assert_nothing_raised do
          message = feed_unlock_confirmation("NotSupported")
        end

        assert_equal "received", message.status
        assert_equal "NotSupported", message.payload.dig("response", "status")
      end

      # TC_018_1 (the headline case): a plug must be releasable mid-charge. The
      # CSMS unlocks the connector of an ACTIVE session, then the station's
      # follow-on unwind (Finishing -> StopTransaction[UnlockCommand] ->
      # Available) is driven entirely through the real inbound handlers, proving
      # the active session is cleanly stopped.
      test "TC_018_1 releases the connector and stops the active session mid-charge" do
        session = create_charging_session(@cp, connector_id: 1, status: "Charging", start_meter_value: 0)

        UnlockConnectorJob.perform_now(@cp.id, 1)

        frame = last_frame_on_station_stream
        assert_equal 2, frame[0], "expected the UnlockConnector CALL to be broadcast"
        assert_equal "UnlockConnector", frame[2]
        assert_equal({ "connectorId" => 1 }, frame[3])

        message = feed_unlock_confirmation("Unlocked")
        assert_equal "received", message.status

        # Station unwinds the transaction: connector transitions to Finishing.
        finishing = Actions::StatusNotificationHandler.new(
          @cp, SecureRandom.uuid,
          { "connectorId" => 1, "status" => "Finishing", "errorCode" => "NoError" }
        ).call
        assert_equal({}, finishing, "StatusNotification must be acknowledged")

        # Station stops the transaction, citing the unlock as the reason.
        stop = Actions::StopTransactionHandler.new(
          @cp, SecureRandom.uuid,
          {
            "transactionId" => session.transaction_id,
            "reason" => "UnlockCommand",
            "meterStop" => 1000,
            "timestamp" => Time.current.iso8601
          }
        ).call
        assert_equal "Accepted", stop.dig("idTagInfo", "status")

        session.reload
        assert_not_nil session.stopped_at, "session must be stopped"
        assert_equal "UnlockCommand", session.stop_reason
        refute session.active?, "session must no longer be active"

        # Connector returns to Available once the cable is released.
        available = Actions::StatusNotificationHandler.new(
          @cp, SecureRandom.uuid,
          { "connectorId" => 1, "status" => "Available", "errorCode" => "NoError" }
        ).call
        assert_equal({}, available, "StatusNotification must be acknowledged")
      end

      private

      def last_frame_on_station_stream
        entries = broadcasts(ChargePointChannel.broadcasting_for(@cp))
        assert entries.any?,
          "nothing was broadcast on the stream the station socket subscribes to"
        JSON.parse(JSON.parse(entries.last)["message"])
      end

      def feed_unlock_confirmation(status)
        message = Message.find_by!(charge_point: @cp, action: "UnlockConnector")
        MessageHandler.new(@cp, [ 3, message.message_id, { "status" => status } ].to_json).process
        message.reload
      end
    end
  end
end
