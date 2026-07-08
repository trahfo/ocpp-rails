# frozen_string_literal: true

require "test_helper"
require_relative "../support/ocpp_test_helper"

module Ocpp
  module Rails
    # OCTT TC_019_1 (retrieve all keys) and TC_019_2 (retrieve one key): the
    # Central System delivers a GetConfiguration.req, records it as a pending
    # outbound Message, and records the confirmation against that Message.
    class GetConfigurationJobTest < ActiveSupport::TestCase
      include ActionCable::TestHelper
      include OcppTestHelper

      setup do
        @charge_point = create_charge_point
      end

      test "TC_019_1 retrieving all keys delivers a GetConfiguration CALL with no key list and records a pending Message" do
        GetConfigurationJob.perform_now(@charge_point.id)

        frame = last_frame_on_station_stream
        message = Message.find_by!(charge_point: @charge_point, action: "GetConfiguration")

        assert_equal 2, frame[0], "expected a CALL frame"
        assert_equal message.message_id, frame[1]
        assert_equal "GetConfiguration", frame[2]
        assert_equal({}, frame[3])
        assert_equal "pending", message.status
      end

      test "TC_019_2 retrieving a single key delivers a GetConfiguration CALL with that key" do
        GetConfigurationJob.perform_now(@charge_point.id, [ "SupportedFeatureProfiles" ])

        frame = last_frame_on_station_stream
        assert_equal "GetConfiguration", frame[2]
        assert_equal({ "key" => [ "SupportedFeatureProfiles" ] }, frame[3])
      end

      test "configuration response is recorded" do
        GetConfigurationJob.perform_now(@charge_point.id)
        msg = Message.find_by!(charge_point: @charge_point, action: "GetConfiguration")

        conf = {
          "configurationKey" => [ { "key" => "HeartbeatInterval", "readonly" => false, "value" => "300" } ],
          "unknownKey" => []
        }
        MessageHandler.new(@charge_point, [ 3, msg.message_id, conf ].to_json).process

        assert_equal "received", msg.reload.status
        assert msg.payload["response"]["configurationKey"].present?
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
