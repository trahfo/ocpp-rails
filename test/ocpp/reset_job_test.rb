# frozen_string_literal: true

require "test_helper"
require_relative "../support/ocpp_test_helper"

module Ocpp
  module Rails
    # OCTT TC_013_CSMS (Hard Reset) and TC_014_CSMS (Soft Reset): the Central
    # System delivers a Reset.req of the requested type, records it as a pending
    # outbound Message, records the confirmation, and the station re-registers
    # afterward through the existing Boot/Status handlers.
    class ResetJobTest < ActiveSupport::TestCase
      include ActionCable::TestHelper
      include OcppTestHelper

      setup do
        @charge_point = create_charge_point
      end

      test "Hard reset delivers a Reset CALL with type Hard and records a pending Message" do
        ResetJob.perform_now(@charge_point.id, "Hard")

        frame = last_frame_on_station_stream
        message = Message.find_by!(charge_point: @charge_point, action: "Reset")

        assert_equal 2, frame[0], "expected a CALL frame"
        assert_equal message.message_id, frame[1]
        assert_equal "Reset", frame[2]
        assert_equal({ "type" => "Hard" }, frame[3])
        assert_equal "pending", message.status
      end

      test "Soft reset delivers a Reset CALL with type Soft" do
        ResetJob.perform_now(@charge_point.id, "Soft")

        frame = last_frame_on_station_stream
        assert_equal "Reset", frame[2]
        assert_equal({ "type" => "Soft" }, frame[3])
      end

      test "accepted Reset confirmation is recorded" do
        ResetJob.perform_now(@charge_point.id, "Hard")
        message = Message.find_by!(charge_point: @charge_point, action: "Reset")

        MessageHandler.new(@charge_point, [ 3, message.message_id, { "status" => "Accepted" } ].to_json).process

        assert_equal "received", message.reload.status
        assert_equal "Accepted", message.payload["response"]["status"]
      end

      test "charge point re-registers after rebooting from a hard reset" do
        ResetJob.perform_now(@charge_point.id, "Hard")
        message = Message.find_by!(charge_point: @charge_point, action: "Reset")
        MessageHandler.new(@charge_point, [ 3, message.message_id, { "status" => "Accepted" } ].to_json).process

        boot = Actions::BootNotificationHandler.new(
          @charge_point, SecureRandom.uuid, build_boot_notification_request.stringify_keys
        ).call
        assert_equal "Accepted", boot["status"]

        ack = Actions::StatusNotificationHandler.new(
          @charge_point, SecureRandom.uuid,
          { "connectorId" => 1, "status" => "Available", "errorCode" => "NoError" }
        ).call
        assert_equal({}, ack)
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
