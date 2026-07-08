# frozen_string_literal: true

require "test_helper"
require_relative "../support/ocpp_test_helper"

module Ocpp
  module Rails
    # Core-profile ChangeAvailability, referenced by the OCTT Reservation
    # "Unavailable" case: the Central System delivers a ChangeAvailability.req to
    # switch a connector (or the whole charge point) Operative/Inoperative,
    # records it as a pending outbound Message, and records the confirmation
    # whether the station accepts it immediately or schedules it for later.
    class ChangeAvailabilityJobTest < ActiveSupport::TestCase
      include ActionCable::TestHelper
      include OcppTestHelper

      setup do
        @charge_point = create_charge_point
      end

      test "Inoperative ChangeAvailability CALL is broadcast and recorded as pending" do
        ChangeAvailabilityJob.perform_now(@charge_point.id, 1, "Inoperative")

        frame = last_frame_on_station_stream
        message = Message.find_by!(charge_point: @charge_point, action: "ChangeAvailability")

        assert_equal 2, frame[0], "expected a CALL frame"
        assert_equal message.message_id, frame[1]
        assert_equal "ChangeAvailability", frame[2]
        assert_equal({ "connectorId" => 1, "type" => "Inoperative" }, frame[3])
        assert_equal "pending", message.status
      end

      test "Operative ChangeAvailability for the whole charge point targets connectorId 0" do
        ChangeAvailabilityJob.perform_now(@charge_point.id, 0, "Operative")

        frame = last_frame_on_station_stream
        assert_equal "ChangeAvailability", frame[2]
        assert_equal({ "connectorId" => 0, "type" => "Operative" }, frame[3])
      end

      test "accepted ChangeAvailability confirmation is recorded" do
        ChangeAvailabilityJob.perform_now(@charge_point.id, 1, "Inoperative")
        message = Message.find_by!(charge_point: @charge_point, action: "ChangeAvailability")

        MessageHandler.new(@charge_point, [ 3, message.message_id, { "status" => "Accepted" } ].to_json).process

        assert_equal "received", message.reload.status
        assert_equal "Accepted", message.payload["response"]["status"]
      end

      test "Scheduled ChangeAvailability confirmation is recorded without error" do
        ChangeAvailabilityJob.perform_now(@charge_point.id, 1, "Inoperative")
        message = Message.find_by!(charge_point: @charge_point, action: "ChangeAvailability")

        assert_nothing_raised do
          MessageHandler.new(@charge_point, [ 3, message.message_id, { "status" => "Scheduled" } ].to_json).process
        end

        assert_equal "received", message.reload.status
        assert_equal "Scheduled", message.payload["response"]["status"]
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
