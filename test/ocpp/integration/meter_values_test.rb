# frozen_string_literal: true

require "test_helper"
require_relative "../../support/ocpp_test_helper"

module Ocpp
  module Rails
    class MeterValuesTest < ActiveSupport::TestCase
      include OcppTestHelper

      setup do
        @charge_point = create_charge_point(
          connected: true,
          status: "Charging"
        )
        @connector_id = 1
        @id_tag = "RFID#{SecureRandom.hex(4)}"
        @session = create_charging_session(
          @charge_point,
          connector_id: @connector_id,
          id_tag: @id_tag,
          status: "Charging",
          started_at: 30.minutes.ago,
          start_meter_value: 1000
        )
      end

      test "valid meter values message during transaction" do
        request = build_meter_values_request(
          connector_id: @connector_id,
          transaction_id: @session.transaction_id,
          meter_values: [build_meter_value]
        )

        message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "inbound",
          action: "MeterValues",
          message_type: "CALL",
          payload: request,
          status: "received"
        )

        assert message.persisted?
        assert_equal "MeterValues", message.action
        assert_equal @connector_id, message.payload["connectorId"]
      end

      test "meter values requires connector id" do
        request = build_meter_values_request(
          connector_id: @connector_id,
          transaction_id: @session.transaction_id
        )

        assert request[:connectorId].present?
        assert_kind_of Integer, request[:connectorId]
        assert request[:connectorId] > 0
      end

      test "meter values requires meter value array" do
        request = build_meter_values_request(
          connector_id: @connector_id,
          transaction_id: @session.transaction_id
        )

        assert request[:meterValue].present?
        assert_kind_of Array, request[:meterValue]
        assert request[:meterValue].any?
      end

      test "meter values can include transaction id" do
        request = build_meter_values_request(
          connector_id: @connector_id,
          transaction_id: @session.transaction_id
        )

        assert_equal @session.transaction_id, request[:transactionId]
      end

      test "meter values without transaction id for connector" do
        request = build_meter_values_request(
          connector_id: @connector_id,
          transaction_id: nil
        )

        assert request[:transactionId].nil?
        assert request[:connectorId].present?
      end

      test "meter value with energy measurand" do
        meter_value = build_meter_value(
          values: [
            {
              value: "12345",
              context: "Sample.Periodic",
              measurand: "Energy.Active.Import.Register",
              unit: "Wh"
            }
          ]
        )

        assert_equal "12345", meter_value[:sampledValue][0][:value]
        assert_equal "Energy.Active.Import.Register", meter_value[:sampledValue][0][:measurand]
        assert_equal "Wh", meter_value[:sampledValue][0][:unit]
      end

      test "meter value with power measurand" do
        meter_value = build_meter_value(
          values: [
            {
              value: "7200",
              measurand: "Power.Active.Import",
              unit: "W"
            }
          ]
        )

        assert_equal "7200", meter_value[:sampledValue][0][:value]
        assert_equal "Power.Active.Import", meter_value[:sampledValue][0][:measurand]
        assert_equal "W", meter_value[:sampledValue][0][:unit]
      end

      test "meter value with current measurand" do
        meter_value = build_meter_value(
          values: [
            {
              value: "32.5",
              measurand: "Current.Import",
              unit: "A"
            }
          ]
        )

        assert_equal "32.5", meter_value[:sampledValue][0][:value]
        assert_equal "Current.Import", meter_value[:sampledValue][0][:measurand]
        assert_equal "A", meter_value[:sampledValue][0][:unit]
      end

      test "meter value with voltage measurand" do
        meter_value = build_meter_value(
          values: [
            {
              value: "230.5",
              measurand: "Voltage",
              unit: "V"
            }
          ]
        )

        assert_equal "230.5", meter_value[:sampledValue][0][:value]
        assert_equal "Voltage", meter_value[:sampledValue][0][:measurand]
        assert_equal "V", meter_value[:sampledValue][0][:unit]
      end

      test "meter value with SoC measurand" do
        meter_value = build_meter_value(
          values: [
            {
              value: "65",
              measurand: "SoC",
              unit: "Percent"
            }
          ]
        )

        assert_equal "65", meter_value[:sampledValue][0][:value]
        assert_equal "SoC", meter_value[:sampledValue][0][:measurand]
        assert_equal "Percent", meter_value[:sampledValue][0][:unit]
      end

      test "meter value with temperature measurand" do
        meter_value = build_meter_value(
          values: [
            {
              value: "35.2",
              measurand: "Temperature",
              unit: "Celsius"
            }
          ]
        )

        assert_equal "35.2", meter_value[:sampledValue][0][:value]
        assert_equal "Temperature", meter_value[:sampledValue][0][:measurand]
        assert_equal "Celsius", meter_value[:sampledValue][0][:unit]
      end

      test "meter value with multiple sampled values" do
        meter_value = build_meter_value(
          values: [
            { value: "12345", measurand: "Energy.Active.Import.Register", unit: "Wh" },
            { value: "7200", measurand: "Power.Active.Import", unit: "W" },
            { value: "32.5", measurand: "Current.Import", unit: "A" },
            { value: "230.5", measurand: "Voltage", unit: "V" }
          ]
        )

        assert_equal 4, meter_value[:sampledValue].length
      end

      test "meter value with Sample.Periodic context" do
        meter_value = build_meter_value(
          values: [
            {
              value: "12345",
              context: "Sample.Periodic",
              measurand: "Energy.Active.Import.Register",
              unit: "Wh"
            }
          ]
        )

        assert_equal "Sample.Periodic", meter_value[:sampledValue][0][:context]
      end

      test "meter value with Sample.Clock context" do
        meter_value = build_meter_value(
          values: [
            {
              value: "12345",
              context: "Sample.Clock",
              measurand: "Energy.Active.Import.Register",
              unit: "Wh"
            }
          ]
        )

        assert_equal "Sample.Clock", meter_value[:sampledValue][0][:context]
      end

      test "meter value with Transaction.Begin context" do
        meter_value = build_meter_value(
          values: [
            {
              value: "1000",
              context: "Transaction.Begin",
              measurand: "Energy.Active.Import.Register",
              unit: "Wh"
            }
          ]
        )

        assert_equal "Transaction.Begin", meter_value[:sampledValue][0][:context]
      end

      test "meter value with Transaction.End context" do
        meter_value = build_meter_value(
          values: [
            {
              value: "15000",
              context: "Transaction.End",
              measurand: "Energy.Active.Import.Register",
              unit: "Wh"
            }
          ]
        )

        assert_equal "Transaction.End", meter_value[:sampledValue][0][:context]
      end

      test "meter value with Interruption.Begin context" do
        meter_value = build_meter_value(
          values: [
            {
              value: "8000",
              context: "Interruption.Begin",
              measurand: "Energy.Active.Import.Register",
              unit: "Wh"
            }
          ]
        )

        assert_equal "Interruption.Begin", meter_value[:sampledValue][0][:context]
      end

      test "meter value with Interruption.End context" do
        meter_value = build_meter_value(
          values: [
            {
              value: "8000",
              context: "Interruption.End",
              measurand: "Energy.Active.Import.Register",
              unit: "Wh"
            }
          ]
        )

        assert_equal "Interruption.End", meter_value[:sampledValue][0][:context]
      end

      test "meter value with three-phase current readings" do
        meter_value = build_meter_value(
          values: [
            { value: "32.5", measurand: "Current.Import", unit: "A", phase: "L1" },
            { value: "31.8", measurand: "Current.Import", unit: "A", phase: "L2" },
            { value: "33.2", measurand: "Current.Import", unit: "A", phase: "L3" }
          ]
        )

        assert_equal "L1", meter_value[:sampledValue][0][:phase]
        assert_equal "L2", meter_value[:sampledValue][1][:phase]
        assert_equal "L3", meter_value[:sampledValue][2][:phase]
      end

      test "meter value with phase information" do
        meter_value = build_meter_value(
          values: [
            {
              value: "32.5",
              measurand: "Current.Import",
              unit: "A",
              phase: "L1"
            }
          ]
        )

        assert_equal "L1", meter_value[:sampledValue][0][:phase]
      end

      test "meter value with location Inlet" do
        meter_value = build_meter_value(
          values: [
            {
              value: "12345",
              measurand: "Energy.Active.Import.Register",
              unit: "Wh",
              location: "Inlet"
            }
          ]
        )

        assert_equal "Inlet", meter_value[:sampledValue][0][:location]
      end

      test "meter value with location Outlet" do
        meter_value = build_meter_value(
          values: [
            {
              value: "12345",
              measurand: "Energy.Active.Import.Register",
              unit: "Wh",
              location: "Outlet"
            }
          ]
        )

        assert_equal "Outlet", meter_value[:sampledValue][0][:location]
      end

      test "meter value with location Body" do
        meter_value = build_meter_value(
          values: [
            {
              value: "35.2",
              measurand: "Temperature",
              unit: "Celsius",
              location: "Body"
            }
          ]
        )

        assert_equal "Body", meter_value[:sampledValue][0][:location]
      end

      test "meter value with format Raw" do
        meter_value = build_meter_value(
          values: [
            {
              value: "12345",
              measurand: "Energy.Active.Import.Register",
              unit: "Wh",
              format: "Raw"
            }
          ]
        )

        assert_equal "Raw", meter_value[:sampledValue][0][:format]
      end

      test "meter value with format SignedData" do
        meter_value = build_meter_value(
          values: [
            {
              value: "12345",
              measurand: "Energy.Active.Import.Register",
              unit: "Wh",
              format: "SignedData"
            }
          ]
        )

        assert_equal "SignedData", meter_value[:sampledValue][0][:format]
      end

      test "meter value requires timestamp" do
        meter_value = build_meter_value

        assert meter_value[:timestamp].present?
        assert_match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/, meter_value[:timestamp])
      end

      test "meter values creates meter value records" do
        request = build_meter_values_request(
          connector_id: @connector_id,
          transaction_id: @session.transaction_id
        )

        assert_difference "MeterValue.count", 1 do
          create_meter_value(
            @charge_point,
            @session,
            connector_id: @connector_id,
            measurand: "Energy.Active.Import.Register",
            value: 12345,
            unit: "Wh",
            timestamp: Time.current
          )
        end
      end

      test "meter values persists message correctly" do
        request = build_meter_values_request(
          connector_id: @connector_id,
          transaction_id: @session.transaction_id
        )

        message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "inbound",
          action: "MeterValues",
          message_type: "CALL",
          payload: request,
          status: "received"
        )

        assert message.persisted?
        assert_equal @charge_point.id, message.charge_point_id
        assert_equal "inbound", message.direction
        assert_equal "CALL", message.message_type
        assert_equal "MeterValues", message.action
        assert_instance_of Hash, message.payload
      end

      test "meter values with valid OCPP message format" do
        message_id = SecureRandom.uuid
        request = build_meter_values_request(
          connector_id: @connector_id,
          transaction_id: @session.transaction_id
        )

        call_message = build_call_message(
          action: "MeterValues",
          payload: request,
          message_id: message_id
        )

        assert_valid_call_message(call_message)
        assert_equal "MeterValues", call_message[2]
        assert_equal @connector_id, call_message[3][:connectorId]
      end

      test "meter values response with valid OCPP message format" do
        message_id = SecureRandom.uuid
        response_payload = {}

        callresult_message = build_callresult_message(
          message_id: message_id,
          payload: response_payload
        )

        assert_valid_callresult_message(callresult_message)
        # MeterValues.conf has empty payload
        assert_equal({}, callresult_message[2])
      end

      test "meter values can be queried by session" do
        mv1 = create_meter_value(@charge_point, @session, value: 5000)
        mv2 = create_meter_value(@charge_point, @session, value: 10000)
        mv3 = create_meter_value(@charge_point, @session, value: 15000)

        session_meter_values = @session.meter_values
        assert_includes session_meter_values, mv1
        assert_includes session_meter_values, mv2
        assert_includes session_meter_values, mv3
      end

      test "meter values can be queried by charge point" do
        mv1 = create_meter_value(@charge_point, @session)
        mv2 = create_meter_value(@charge_point, @session)

        cp_meter_values = @charge_point.meter_values
        assert_includes cp_meter_values, mv1
        assert_includes cp_meter_values, mv2
      end

      test "meter values can be filtered by measurand" do
        energy_mv = create_meter_value(
          @charge_point,
          @session,
          measurand: "Energy.Active.Import.Register"
        )
        power_mv = create_meter_value(
          @charge_point,
          @session,
          measurand: "Power.Active.Import"
        )

        energy_values = @charge_point.meter_values.energy
        assert_includes energy_values, energy_mv
        refute_includes energy_values, power_mv
      end

      test "meter values can be ordered by timestamp" do
        mv1 = create_meter_value(@charge_point, @session, timestamp: 3.minutes.ago)
        mv2 = create_meter_value(@charge_point, @session, timestamp: 2.minutes.ago)
        mv3 = create_meter_value(@charge_point, @session, timestamp: 1.minute.ago)

        recent_values = @charge_point.meter_values.recent
        assert_equal mv3.id, recent_values.first.id
      end

      test "meter values during active transaction" do
        assert @session.active?

        mv = create_meter_value(@charge_point, @session, value: 8000)

        assert mv.persisted?
        assert_equal @session.id, mv.charging_session_id
      end

      test "meter values with all standard measurands" do
        measurands = [
          "Energy.Active.Import.Register",
          "Energy.Active.Export.Register",
          "Energy.Reactive.Import.Register",
          "Energy.Reactive.Export.Register",
          "Energy.Active.Import.Interval",
          "Energy.Active.Export.Interval",
          "Energy.Reactive.Import.Interval",
          "Energy.Reactive.Export.Interval",
          "Power.Active.Import",
          "Power.Active.Export",
          "Power.Offered",
          "Power.Reactive.Import",
          "Power.Reactive.Export",
          "Power.Factor",
          "Current.Import",
          "Current.Export",
          "Current.Offered",
          "Voltage",
          "Frequency",
          "Temperature",
          "SoC",
          "RPM"
        ]

        measurands.each do |measurand|
          meter_value = build_meter_value(
            values: [
              {
                value: "100",
                measurand: measurand,
                unit: "Wh"
              }
            ]
          )

          assert_equal measurand, meter_value[:sampledValue][0][:measurand]
        end
      end

      test "meter values periodic sampling during charging" do
        # Simulate periodic meter values every 5 minutes
        timestamps = [
          25.minutes.ago,
          20.minutes.ago,
          15.minutes.ago,
          10.minutes.ago,
          5.minutes.ago
        ]

        meter_values = timestamps.map.with_index do |timestamp, index|
          create_meter_value(
            @charge_point,
            @session,
            value: 1000 + (index * 3000),
            timestamp: timestamp
          )
        end

        assert_equal 5, meter_values.length
        assert_equal 5, @session.meter_values.count
      end

      test "meter values can track energy progression" do
        mv1 = create_meter_value(@charge_point, @session, value: 1000, timestamp: 3.minutes.ago)
        mv2 = create_meter_value(@charge_point, @session, value: 5000, timestamp: 2.minutes.ago)
        mv3 = create_meter_value(@charge_point, @session, value: 10000, timestamp: 1.minute.ago)

        values_ordered = @session.meter_values.order(timestamp: :asc)
        assert_equal mv1.id, values_ordered.first.id
        assert_equal mv3.id, values_ordered.last.id
        assert mv1.value < mv2.value
        assert mv2.value < mv3.value
      end

      test "meter values without charging session" do
        # Meter values can be sent outside of a transaction
        mv = create_meter_value(@charge_point, nil, connector_id: @connector_id)

        assert mv.persisted?
        assert_nil mv.charging_session_id
        assert_equal @charge_point.id, mv.charge_point_id
      end

      test "meter values for multiple sessions" do
        session2 = create_charging_session(
          @charge_point,
          connector_id: 2,
          id_tag: "TAG_002"
        )

        mv1 = create_meter_value(@charge_point, @session, value: 5000)
        mv2 = create_meter_value(@charge_point, session2, value: 8000)

        assert_equal 1, @session.meter_values.count
        assert_equal 1, session2.meter_values.count
        refute_equal mv1.charging_session_id, mv2.charging_session_id
      end

      test "meter values response has empty payload" do
        # According to OCPP 1.6, MeterValues.conf has no payload
        request = build_meter_values_request(
          connector_id: @connector_id,
          transaction_id: @session.transaction_id
        )

        Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "inbound",
          action: "MeterValues",
          message_type: "CALL",
          payload: request,
          status: "received"
        )

        # Response should be empty
        response = {}
        assert_equal({}, response)
      end
    end
  end
end
