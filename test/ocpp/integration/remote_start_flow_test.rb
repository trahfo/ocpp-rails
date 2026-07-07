# frozen_string_literal: true

require "test_helper"
require_relative "../../support/ocpp_test_helper"

module Ocpp
  module Rails
    # OCTT regression coverage for the Remote Start scenarios. Every step drives
    # the real production code path: the outbound CALL comes from
    # RemoteStartTransactionJob, and the station's replies are fed through the
    # actual Authorize/StartTransaction/StatusNotification handlers.
    #
    #   TC_010    Remote Start - cable plugged in first
    #   TC_011_1  Remote Start - remote start first
    #   TC_011_2  Remote Start - time out (never plugged in / no StartTransaction)
    class RemoteStartFlowTest < ActiveSupport::TestCase
      include ActionCable::TestHelper
      include OcppTestHelper

      setup { @cp = create_charge_point }

      # TC_010: the driver plugs the cable in (connector goes Preparing) before
      # the operator triggers the remote start. The station then authorizes and
      # opens the transaction.
      test "TC_010 remote start with cable plugged in first" do
        assert_equal({}, status_notification("Preparing"))

        RemoteStartTransactionJob.perform_now(@cp.id, 1, "RFID_RS")
        assert_remote_start_call(connector_id: 1, id_tag: "RFID_RS")

        authorize = Actions::AuthorizeHandler.new(@cp, new_message_id, { "idTag" => "RFID_RS" }).call
        assert_equal "Accepted", authorize.dig("idTagInfo", "status")

        result = nil
        assert_difference "Ocpp::Rails::ChargingSession.count", 1 do
          result = start_transaction(connector_id: 1, id_tag: "RFID_RS")
        end
        assert_equal "Accepted", result.dig("idTagInfo", "status")

        session = @cp.charging_sessions.order(:created_at).last
        assert_equal 1, session.connector_id
        assert_equal "RFID_RS", session.id_tag

        assert_equal({}, status_notification("Charging"))
      end

      # TC_011_1: the operator triggers the remote start first, on an idle
      # connector; the driver plugs in afterwards (Preparing) and the station
      # then opens the transaction.
      test "TC_011_1 remote start before the cable is plugged in" do
        assert_equal "Available", @cp.reload.status

        RemoteStartTransactionJob.perform_now(@cp.id, 1, "RFID_RS")
        assert_remote_start_call(connector_id: 1, id_tag: "RFID_RS")

        assert_equal({}, status_notification("Preparing"))

        result = nil
        assert_difference "Ocpp::Rails::ChargingSession.count", 1 do
          result = start_transaction(connector_id: 1, id_tag: "RFID_RS")
        end
        assert_equal "Accepted", result.dig("idTagInfo", "status")
        assert_equal 1, @cp.charging_sessions.count
      end

      # TC_011_2: the remote start is accepted by the station but the driver
      # never plugs in, so no StartTransaction arrives. The connector goes
      # Preparing and then falls back to Available without a session opening.
      test "TC_011_2 remote start times out without a StartTransaction" do
        RemoteStartTransactionJob.perform_now(@cp.id, 1, "RFID_RS")
        assert_remote_start_call(connector_id: 1, id_tag: "RFID_RS")

        assert_no_difference "Ocpp::Rails::ChargingSession.count" do
          assert_equal({}, status_notification("Preparing"))
          assert_equal({}, status_notification("Available"))
        end

        assert_equal 0, @cp.charging_sessions.count
      end

      private

      def new_message_id
        SecureRandom.uuid
      end

      def status_notification(status, connector_id: 1)
        payload = {
          "connectorId" => connector_id,
          "status" => status,
          "errorCode" => "NoError",
          "timestamp" => Time.current.iso8601
        }
        Actions::StatusNotificationHandler.new(@cp, new_message_id, payload).call
      end

      def start_transaction(connector_id:, id_tag:, meter_start: 0)
        payload = {
          "connectorId" => connector_id,
          "idTag" => id_tag,
          "meterStart" => meter_start,
          "timestamp" => Time.current.iso8601
        }
        Actions::StartTransactionHandler.new(@cp, new_message_id, payload).call
      end

      # Asserts the last frame broadcast on the station's WebSocket stream is the
      # expected RemoteStartTransaction CALL, matched against the pending Message
      # the job recorded.
      def assert_remote_start_call(connector_id:, id_tag:)
        frame = last_frame_on_station_stream
        message = Message.find_by!(charge_point: @cp, action: "RemoteStartTransaction")

        assert_equal(
          [ 2, message.message_id, "RemoteStartTransaction",
            { "connectorId" => connector_id, "idTag" => id_tag } ],
          frame
        )
        assert_equal "pending", message.status
      end

      def last_frame_on_station_stream
        entries = broadcasts(ChargePointChannel.broadcasting_for(@cp))
        assert entries.any?,
          "nothing was broadcast on the stream the station socket subscribes to"
        JSON.parse(JSON.parse(entries.last)["message"])
      end
    end
  end
end
