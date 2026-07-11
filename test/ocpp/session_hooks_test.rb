# frozen_string_literal: true

require "test_helper"
require_relative "../support/ocpp_test_helper"

module Ocpp
  module Rails
    # Session lifecycle hooks: consumers register hooks that fire when a
    # ChargingSession starts or stops on the wire, replacing polling on
    # ChargingSession.active.
    class SessionHooksTest < ActiveSupport::TestCase
      include OcppTestHelper
      include ActiveJob::TestHelper

      class AsyncRecordingHook
        def self.events
          @events ||= []
        end

        def async?
          true
        end

        def call(session, event)
          self.class.events << [ session.id, event ]
        end
      end

      class RecordingHook
        attr_reader :calls

        def initialize
          @calls = []
        end

        def call(session, event)
          @calls << [ session, event ]
        end
      end

      setup do
        @cp = create_charge_point
        @hook = RecordingHook.new
        Ocpp::Rails.configuration.session_hooks = [ @hook ]
      end

      teardown do
        Ocpp::Rails.configuration.session_hooks = []
      end

      test "started hook fires with the created session" do
        response = start_transaction

        session = @cp.charging_sessions.find_by!(transaction_id: response["transactionId"])
        assert_equal [ [ session, "started" ] ], @hook.calls
      end

      test "stopped hook fires after the session and its transaction data are persisted" do
        start_transaction
        session = @cp.charging_sessions.active.find_by!(connector_id: 1)

        seen = nil
        Ocpp::Rails.configuration.session_hooks = [
          lambda do |s, event|
            seen = {
              event: event,
              active: s.active?,
              transaction_end_values: s.meter_values.where(context: "Transaction.End").count
            }
          end
        ]

        stop_transaction(session, extra_payload: {
          "transactionData" => [
            {
              "timestamp" => Time.current.iso8601,
              "sampledValue" => [
                { "value" => "1500", "context" => "Transaction.End",
                  "measurand" => "Energy.Active.Import.Register", "unit" => "Wh" }
              ]
            }
          ]
        })

        assert_equal "stopped", seen[:event]
        assert_not seen[:active], "session must already be stopped when the hook runs"
        assert_equal 1, seen[:transaction_end_values],
          "Transaction.End meter values must be persisted before the stopped hook fires"
      end

      # A station retransmitting StartTransaction resumes the open session;
      # re-firing would duplicate downstream objects (e.g. OCPI sessions).
      test "duplicate StartTransaction resumes the session without re-firing started" do
        first = start_transaction
        second = start_transaction

        assert_equal first["transactionId"], second["transactionId"]
        assert_equal 1, @hook.calls.count { |_, event| event == "started" }
      end

      test "a raising hook does not corrupt the OCPP response" do
        raising = Object.new
        def raising.call(_session, _event) = raise "hook exploded"
        Ocpp::Rails.configuration.session_hooks = [ raising, @hook ]

        response = start_transaction

        assert_equal "Accepted", response.dig("idTagInfo", "status")
        assert_operator response["transactionId"], :>, 0
        assert_equal [ "started" ], @hook.calls.map(&:last),
          "hooks after the raising one must still run"
      end

      test "async hook runs through SessionAsyncHookJob with the event" do
        Ocpp::Rails.configuration.session_hooks = [ AsyncRecordingHook.new ]
        AsyncRecordingHook.events.clear

        response = nil
        perform_enqueued_jobs do
          response = start_transaction
        end

        session = @cp.charging_sessions.find_by!(transaction_id: response["transactionId"])
        assert_equal [ [ session.id, "started" ] ], AsyncRecordingHook.events
      end

      private

      def start_transaction(connector_id: 1, id_tag: "HOOK-TAG")
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

      def stop_transaction(session, meter_stop: 1500, extra_payload: {})
        Actions::StopTransactionHandler.new(
          @cp,
          SecureRandom.uuid,
          {
            "transactionId" => session.transaction_id,
            "meterStop" => meter_stop,
            "timestamp" => Time.current.iso8601
          }.merge(extra_payload)
        ).call
      end
    end
  end
end
