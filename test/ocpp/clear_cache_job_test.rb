# frozen_string_literal: true

require "test_helper"
require_relative "../support/ocpp_test_helper"

module Ocpp
  module Rails
    # OCTT TC_061_CSMS: the Central System clears the charge point's
    # authorization cache by delivering a ClearCache.req (empty payload) and
    # recording the confirmation against the pending outbound Message.
    class ClearCacheJobTest < ActiveSupport::TestCase
      include ActionCable::TestHelper
      include OcppTestHelper

      setup do
        @charge_point = create_charge_point
      end

      test "ClearCache CALL is broadcast and recorded as pending" do
        ClearCacheJob.perform_now(@charge_point.id)

        frame = last_frame_on_station_stream
        message = Message.find_by!(charge_point: @charge_point, action: "ClearCache")

        assert_equal 2, frame[0], "expected a CALL frame"
        assert_equal message.message_id, frame[1]
        assert_equal "ClearCache", frame[2]
        assert_equal({}, frame[3])
        assert_equal "pending", message.status
      end

      test "accepted ClearCache confirmation is recorded" do
        ClearCacheJob.perform_now(@charge_point.id)
        message = Message.find_by!(charge_point: @charge_point, action: "ClearCache")

        MessageHandler.new(@charge_point, [ 3, message.message_id, { "status" => "Accepted" } ].to_json).process

        assert_equal "received", message.reload.status
        assert_equal "Accepted", message.payload["response"]["status"]
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
