# frozen_string_literal: true

require "test_helper"
require_relative "../support/ocpp_test_helper"

module Ocpp
  module Rails
    class TimestampProvenanceTest < ActiveSupport::TestCase
      include OcppTestHelper

      setup do
        @charge_point = create_charge_point
      end

      test "meter value keeps the raw station timestamp and marks it as station time" do
        station_time = "2026-07-01T10:30:00Z"
        payload = {
          "connectorId" => 1,
          "meterValue" => [ {
            "timestamp" => station_time,
            "sampledValue" => [ { "value" => "1200", "unit" => "Wh" } ]
          } ]
        }

        Actions::MeterValuesHandler.new(@charge_point, SecureRandom.uuid, payload).call

        meter_value = @charge_point.meter_values.last
        assert_equal station_time, meter_value.raw_timestamp
        assert_equal "station", meter_value.timestamp_source
        assert_equal Time.parse(station_time), meter_value.timestamp
      end

      test "unparseable meter timestamp is flagged as server fallback, not silently substituted" do
        payload = {
          "connectorId" => 1,
          "meterValue" => [ {
            "timestamp" => "not-a-timestamp",
            "sampledValue" => [ { "value" => "1200", "unit" => "Wh" } ]
          } ]
        }

        Actions::MeterValuesHandler.new(@charge_point, SecureRandom.uuid, payload).call

        meter_value = @charge_point.meter_values.last
        assert_equal "server_fallback", meter_value.timestamp_source
        assert_equal "not-a-timestamp", meter_value.raw_timestamp
        assert_in_delta Time.current.to_f, meter_value.timestamp.to_f, 5
      end

      test "missing meter timestamp is flagged as server fallback" do
        payload = {
          "connectorId" => 1,
          "meterValue" => [ {
            "sampledValue" => [ { "value" => "1200", "unit" => "Wh" } ]
          } ]
        }

        Actions::MeterValuesHandler.new(@charge_point, SecureRandom.uuid, payload).call

        assert_equal "server_fallback", @charge_point.meter_values.last.timestamp_source
      end

      test "session started with an unparseable timestamp is flagged in metadata" do
        payload = {
          "connectorId" => 1,
          "idTag" => "RFID1",
          "meterStart" => 0,
          "timestamp" => "garbage"
        }

        Actions::StartTransactionHandler.new(@charge_point, SecureRandom.uuid, payload).call

        session = @charge_point.charging_sessions.last
        assert_equal "server_fallback", session.metadata["started_at_source"]
        assert_equal "garbage", session.metadata["raw_start_timestamp"]
      end

      test "session started with a valid timestamp is not flagged" do
        payload = {
          "connectorId" => 1,
          "idTag" => "RFID1",
          "meterStart" => 0,
          "timestamp" => "2026-07-01T10:30:00Z"
        }

        Actions::StartTransactionHandler.new(@charge_point, SecureRandom.uuid, payload).call

        session = @charge_point.charging_sessions.last
        assert_nil session.metadata["started_at_source"]
        assert_equal Time.parse("2026-07-01T10:30:00Z"), session.started_at
      end
    end
  end
end
