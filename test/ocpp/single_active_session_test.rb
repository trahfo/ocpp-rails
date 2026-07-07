# frozen_string_literal: true

require "test_helper"
require_relative "../support/ocpp_test_helper"

module Ocpp
  module Rails
    class SingleActiveSessionTest < ActiveSupport::TestCase
      include OcppTestHelper

      setup do
        @charge_point = create_charge_point
      end

      test "duplicate StartTransaction on the same connector resumes the existing session" do
        first = start_transaction
        second = nil

        assert_no_difference "Ocpp::Rails::ChargingSession.count" do
          second = start_transaction
        end

        assert_equal "Accepted", second["idTagInfo"]["status"]
        assert_equal first["transactionId"], second["transactionId"],
          "a replayed StartTransaction must return the already-open transaction"
        assert_equal 1, @charge_point.charging_sessions.active.where(connector_id: 1).count
      end

      test "database rejects a second active session per connector even without the handler" do
        create_charging_session(@charge_point, connector_id: 1)

        assert_raises ActiveRecord::RecordNotUnique do
          @charge_point.charging_sessions.create!(
            connector_id: 1,
            id_tag: "OTHER",
            started_at: Time.current,
            status: "Charging"
          )
        end
      end

      test "a stopped session frees the connector for a new transaction" do
        first = start_transaction
        Actions::StopTransactionHandler.new(@charge_point, SecureRandom.uuid, {
          "transactionId" => first["transactionId"],
          "meterStop" => 500,
          "timestamp" => Time.current.iso8601
        }).call

        second = start_transaction

        refute_equal first["transactionId"], second["transactionId"]
        assert_equal 1, @charge_point.charging_sessions.active.where(connector_id: 1).count
        assert_equal 2, @charge_point.charging_sessions.where(connector_id: 1).count
      end

      test "sessions on different connectors stay independent" do
        start_transaction(connector_id: 1)
        assert_difference "Ocpp::Rails::ChargingSession.count", 1 do
          start_transaction(connector_id: 2)
        end
      end

      private

      def start_transaction(connector_id: 1, id_tag: "RFID1")
        Actions::StartTransactionHandler.new(@charge_point, SecureRandom.uuid, {
          "connectorId" => connector_id,
          "idTag" => id_tag,
          "meterStart" => 0,
          "timestamp" => Time.current.iso8601
        }).call
      end
    end
  end
end
