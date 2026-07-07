# frozen_string_literal: true

require "test_helper"
require_relative "../support/ocpp_test_helper"

module Ocpp
  module Rails
    # The station socket only streams what ChargePointChannel subscribes to
    # (stream_for the charge point record). These tests pin the contract that
    # outbound remote-control CALLs are broadcast on exactly that stream.
    class OutboundDeliveryTest < ActiveSupport::TestCase
      include ActionCable::TestHelper
      include OcppTestHelper

      setup do
        @charge_point = create_charge_point
      end

      test "RemoteStartTransactionJob delivers the CALL frame on the station's stream" do
        RemoteStartTransactionJob.perform_now(@charge_point.id, 1, "RFID1")

        frame = last_frame_on_station_stream
        message = Message.find_by!(charge_point: @charge_point, action: "RemoteStartTransaction")

        assert_equal 2, frame[0], "expected a CALL frame"
        assert_equal message.message_id, frame[1]
        assert_equal "RemoteStartTransaction", frame[2]
        assert_equal({ "connectorId" => 1, "idTag" => "RFID1" }, frame[3])
        assert_equal "pending", message.status
      end

      test "RemoteStopTransactionJob delivers the CALL frame on the station's stream" do
        session = create_charging_session(@charge_point)

        RemoteStopTransactionJob.perform_now(@charge_point.id, session.transaction_id)

        frame = last_frame_on_station_stream
        assert_equal 2, frame[0]
        assert_equal "RemoteStopTransaction", frame[2]
        assert_equal({ "transactionId" => session.transaction_id }, frame[3])
      end

      private

      def last_frame_on_station_stream
        entries = broadcasts(ChargePointChannel.broadcasting_for(@charge_point))
        assert entries.any?,
          "nothing was broadcast on the stream the station socket subscribes to"
        JSON.parse(JSON.parse(entries.last)["message"])
      end
    end

    class ChargePointChannelStreamTest < ActionCable::Channel::TestCase
      tests Ocpp::Rails::ChargePointChannel
      include OcppTestHelper

      test "station subscription streams for its charge point record" do
        charge_point = create_charge_point

        subscribe charge_point_id: charge_point.identifier

        assert subscription.confirmed?
        assert_has_stream_for charge_point
      end

      test "unknown charge point identifier is rejected" do
        subscribe charge_point_id: "UNKNOWN_CP"

        assert subscription.rejected?
      end
    end
  end
end
