# frozen_string_literal: true

require "test_helper"
require_relative "../support/ocpp_test_helper"

module Ocpp
  module Rails
    class WireTransactionIdTest < ActiveSupport::TestCase
      include OcppTestHelper

      setup do
        @charge_point = create_charge_point
      end

      test "start, meter values and stop resolve the session via the wire transactionId only" do
        response = Actions::StartTransactionHandler.new(@charge_point, SecureRandom.uuid, {
          "connectorId" => 1,
          "idTag" => "RFID1",
          "meterStart" => 100,
          "timestamp" => Time.current.iso8601
        }).call

        wire_transaction_id = response["transactionId"]
        session = @charge_point.charging_sessions.last

        assert_kind_of Integer, wire_transaction_id
        assert_equal session.transaction_id, wire_transaction_id
        refute_equal session.id, wire_transaction_id,
          "wire transactionId must not expose the AR primary key"

        Actions::MeterValuesHandler.new(@charge_point, SecureRandom.uuid, {
          "connectorId" => 1,
          "transactionId" => wire_transaction_id,
          "meterValue" => [ {
            "timestamp" => Time.current.iso8601,
            "sampledValue" => [ { "value" => "600", "unit" => "Wh" } ]
          } ]
        }).call

        assert_equal session.id, @charge_point.meter_values.last.charging_session_id,
          "meter value must attach to the session found via the wire transactionId"

        stop_response = Actions::StopTransactionHandler.new(@charge_point, SecureRandom.uuid, {
          "transactionId" => wire_transaction_id,
          "meterStop" => 1100,
          "timestamp" => Time.current.iso8601
        }).call

        assert_equal "Accepted", stop_response["idTagInfo"]["status"]
        assert_not session.reload.active?
      end

      test "wire transaction ids are positive OCPP 1.6 integers and unique" do
        ids = 2.times.map do |i|
          Actions::StartTransactionHandler.new(@charge_point, SecureRandom.uuid, {
            "connectorId" => i + 1,
            "idTag" => "RFID#{i}",
            "meterStart" => 0,
            "timestamp" => Time.current.iso8601
          }).call["transactionId"]
        end

        ids.each do |id|
          assert_kind_of Integer, id
          assert id.positive?
          assert id <= (2**31) - 1, "transactionId must fit a signed 32-bit integer"
        end
        assert_equal ids.uniq, ids
      end

      test "stop with an unknown wire transactionId is Invalid and does not touch other sessions" do
        session = create_charging_session(@charge_point)

        response = Actions::StopTransactionHandler.new(@charge_point, SecureRandom.uuid, {
          "transactionId" => 999_999_999,
          "meterStop" => 42,
          "timestamp" => Time.current.iso8601
        }).call

        assert_equal "Invalid", response["idTagInfo"]["status"]
        assert session.reload.active?
      end
    end
  end
end
