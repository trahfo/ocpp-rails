# frozen_string_literal: true

require "test_helper"
require_relative "../support/ocpp_test_helper"

module Ocpp
  module Rails
    # OCTT TC_021_CSMS (Accepted), TC_040_1_CSMS (NotSupported), and
    # TC_040_2_CSMS (Rejected): the Central System changes a configuration key by
    # delivering a ChangeConfiguration.req, records it as a pending outbound
    # Message, and records the confirmation regardless of the returned status.
    class ChangeConfigurationJobTest < ActiveSupport::TestCase
      include ActionCable::TestHelper
      include OcppTestHelper

      setup do
        @charge_point = create_charge_point
      end

      test "ChangeConfiguration CALL is broadcast and recorded as pending" do
        ChangeConfigurationJob.perform_now(@charge_point.id, "MeterValueSampleInterval", "60")

        frame = last_frame_on_station_stream
        message = Message.find_by!(charge_point: @charge_point, action: "ChangeConfiguration")

        assert_equal 2, frame[0], "expected a CALL frame"
        assert_equal message.message_id, frame[1]
        assert_equal "ChangeConfiguration", frame[2]
        assert_equal({ "key" => "MeterValueSampleInterval", "value" => "60" }, frame[3])
        assert_equal "pending", message.status
      end

      test "accepted ChangeConfiguration confirmation is recorded" do
        ChangeConfigurationJob.perform_now(@charge_point.id, "MeterValueSampleInterval", "60")
        message = Message.find_by!(charge_point: @charge_point, action: "ChangeConfiguration")

        MessageHandler.new(@charge_point, [ 3, message.message_id, { "status" => "Accepted" } ].to_json).process

        assert_equal "received", message.reload.status
        assert_equal "Accepted", message.payload["response"]["status"]
      end

      test "NotSupported ChangeConfiguration confirmation is recorded without error" do
        ChangeConfigurationJob.perform_now(@charge_point.id, "SomeUnknownKey", "42")
        message = Message.find_by!(charge_point: @charge_point, action: "ChangeConfiguration")

        assert_nothing_raised do
          MessageHandler.new(@charge_point, [ 3, message.message_id, { "status" => "NotSupported" } ].to_json).process
        end

        assert_equal "received", message.reload.status
        assert_equal "NotSupported", message.payload["response"]["status"]
      end

      test "Rejected ChangeConfiguration confirmation is recorded without error" do
        ChangeConfigurationJob.perform_now(@charge_point.id, "MeterValueSampleInterval", "60")
        message = Message.find_by!(charge_point: @charge_point, action: "ChangeConfiguration")

        assert_nothing_raised do
          MessageHandler.new(@charge_point, [ 3, message.message_id, { "status" => "Rejected" } ].to_json).process
        end

        assert_equal "received", message.reload.status
        assert_equal "Rejected", message.payload["response"]["status"]
      end

      private

      def last_frame_on_station_stream
        entries = broadcasts(ChargePointChannel.broadcasting_for(@charge_point))
        assert entries.any?, "nothing was broadcast on the station stream"
        JSON.parse(JSON.parse(entries.last)["message"])
      end
    end
  end
end
