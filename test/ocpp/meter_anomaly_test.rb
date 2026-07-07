# frozen_string_literal: true

require "test_helper"
require_relative "../support/ocpp_test_helper"

module Ocpp
  module Rails
    class MeterAnomalyTest < ActiveSupport::TestCase
      include OcppTestHelper

      setup do
        @charge_point = create_charge_point
        @session = create_charging_session(@charge_point, start_meter_value: 1000)
      end

      test "a monotonic energy register series is not flagged" do
        send_meter_value("1200")
        send_meter_value("1500")

        assert_equal [ false, false ], @session.meter_values.energy.order(:id).map(&:flagged)
      end

      test "a decreasing energy register value is flagged, not silently accepted" do
        send_meter_value("2000")
        send_meter_value("1500")

        flagged = @session.meter_values.energy.order(:id).last
        assert flagged.flagged?
        assert_equal "register_decrease", flagged.flag_reason
      end

      test "a register value below meterStart is flagged" do
        send_meter_value("500")

        assert @session.meter_values.energy.last.flagged?
      end

      test "unit normalisation compares kWh against Wh correctly" do
        send_meter_value("2.0", unit: "kWh")   # 2000 Wh
        send_meter_value("1500")               # decrease vs 2000 Wh

        values = @session.meter_values.energy.order(:id)
        assert_not values.first.flagged?
        assert values.last.flagged?
        assert_equal 2000, values.first.value_in_wh
      end

      test "an implausible jump is flagged" do
        original = Ocpp::Rails.configuration.implausible_energy_jump_wh
        Ocpp::Rails.configuration.implausible_energy_jump_wh = 10_000

        send_meter_value("1200")
        send_meter_value("50000")

        assert_equal "implausible_jump", @session.meter_values.energy.order(:id).last.flag_reason
      ensure
        Ocpp::Rails.configuration.implausible_energy_jump_wh = original
      end

      test "non-energy measurands are never flagged by the register check" do
        send_meter_value("230.1", measurand: "Voltage", unit: "V")
        send_meter_value("11.5", measurand: "Voltage", unit: "V")

        assert_equal [ false, false ], @session.meter_values.order(:id).map(&:flagged)
      end

      test "stop below start flags the session instead of computing negative energy" do
        @session.stop!(meter_value: 400)

        assert_nil @session.energy_consumed
        assert_equal "stop_below_start", @session.metadata["energy_anomaly"]
      end

      test "normal stop computes energy as before" do
        @session.stop!(meter_value: 3500)

        assert_equal 2500, @session.energy_consumed
        assert_nil @session.metadata["energy_anomaly"]
      end

      private

      def send_meter_value(value, unit: "Wh", measurand: "Energy.Active.Import.Register")
        Actions::MeterValuesHandler.new(@charge_point, SecureRandom.uuid, {
          "connectorId" => @session.connector_id,
          "transactionId" => @session.transaction_id,
          "meterValue" => [ {
            "timestamp" => Time.current.iso8601,
            "sampledValue" => [ {
              "value" => value, "unit" => unit, "measurand" => measurand
            } ]
          } ]
        }).call
      end
    end
  end
end
