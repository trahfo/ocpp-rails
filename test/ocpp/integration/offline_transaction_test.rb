# frozen_string_literal: true

require "test_helper"
require_relative "../../support/ocpp_test_helper"

module Ocpp
  module Rails
    # OCTT TC_037_1 / TC_037_3 / TC_039: Offline transactions.
    #
    # While the station is offline it caches transaction messages and replays
    # them once the link is restored, carrying the original (past) timestamps.
    # These tests drive the real handlers with late-arriving, out-of-order
    # payloads exactly as the CSMS receives them after reconnection.
    class OfflineTransactionTest < ActiveSupport::TestCase
      include OcppTestHelper

      # Sync hook that rejects one specific offline idTag; every other tag is
      # accepted, matching the CSMS default. Lets a single test drive an
      # Invalid decision for a replayed StartTransaction.
      class OfflineTagHook
        def call(_charge_point_id, id_tag)
          case id_tag
          when "OFFLINE_BAD" then { status: "Invalid" }
          else { status: "Accepted" }
          end
        end
      end

      setup do
        @cp = create_charge_point
        @original_hooks = Ocpp::Rails.configuration.authorization_hooks.dup
        Ocpp::Rails.configuration.authorization_hooks << OfflineTagHook.new
      end

      teardown do
        Ocpp::Rails.configuration.authorization_hooks.replace(@original_hooks)
      end

      # TC_037_1: a StartTransaction cached offline with a valid idTag is
      # replayed late (original timestamp an hour in the past). The CSMS
      # accepts it, opens the session, and acknowledges the follow-up
      # StatusNotification reporting the connector is Charging.
      test "valid offline start is accepted when replayed late" do
        response = nil
        assert_difference "Ocpp::Rails::ChargingSession.count", 1 do
          response = start_transaction(id_tag: "OFFLINE_GOOD", timestamp: 1.hour.ago.iso8601)
        end

        assert_equal "Accepted", response["idTagInfo"]["status"]

        session = @cp.charging_sessions.last
        assert_equal "OFFLINE_GOOD", session.id_tag

        assert_equal({}, status_notification(connector_id: 1, status: "Charging"))
      end

      # TC_037_3: a StartTransaction cached offline with an idTag that is no
      # longer valid must be rejected on replay (status Invalid, transactionId
      # 0) and must not open a session. The station's follow-on messages, a
      # Charging StatusNotification and a StopTransaction for the transaction
      # that never opened server-side, must still be handled gracefully.
      test "invalid offline start is rejected and unwound" do
        response = nil
        assert_no_difference "Ocpp::Rails::ChargingSession.count" do
          response = start_transaction(id_tag: "OFFLINE_BAD")
        end

        assert_equal "Invalid", response["idTagInfo"]["status"]
        assert_equal 0, response["transactionId"]

        assert_equal({}, status_notification(connector_id: 1, status: "Charging"))

        stop_response = nil
        assert_nothing_raised do
          stop_response = stop_transaction(transaction_id: 0, reason: "DeAuthorized")
        end
        assert_kind_of Hash, stop_response

        assert_equal({}, status_notification(connector_id: 1, status: "Finishing"))
      end

      # TC_039: a station that was offline for an entire transaction replays
      # both the StartTransaction and the matching StopTransaction. The CSMS
      # opens the session on the start, then closes it on the stop.
      test "full offline start and stop are replayed" do
        start_response = start_transaction(id_tag: "OFFLINE_GOOD", timestamp: 2.hours.ago.iso8601)
        assert_equal "Accepted", start_response["idTagInfo"]["status"]

        transaction_id = start_response["transactionId"]

        stop_response = stop_transaction(transaction_id: transaction_id, reason: "Local")
        assert_equal "Accepted", stop_response["idTagInfo"]["status"]

        session = @cp.charging_sessions.find_by(transaction_id: transaction_id)
        refute_nil session.stopped_at, "replayed transaction should be stopped"
        assert_equal "Local", session.stop_reason
      end

      private

      def start_transaction(id_tag:, timestamp: Time.current.iso8601)
        Actions::StartTransactionHandler.new(
          @cp,
          SecureRandom.uuid,
          {
            "connectorId" => 1,
            "idTag" => id_tag,
            "meterStart" => 0,
            "timestamp" => timestamp
          }
        ).call
      end

      def stop_transaction(transaction_id:, reason:)
        Actions::StopTransactionHandler.new(
          @cp,
          SecureRandom.uuid,
          {
            "connectorId" => 1,
            "transactionId" => transaction_id,
            "reason" => reason,
            "meterStop" => 1000,
            "timestamp" => Time.current.iso8601
          }
        ).call
      end

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
