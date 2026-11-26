# frozen_string_literal: true

require "test_helper"
require_relative "../support/ocpp_test_helper"

module Ocpp
  module Rails
    class MessageHandlerTest < ActiveSupport::TestCase
      include ActionCable::TestHelper
      include OcppTestHelper

      setup do
        @charge_point = create_charge_point
      end

      test "unexpected handler errors send a generic CALLERROR without exception details" do
        # Missing connectorId makes StartTransactionHandler raise RecordInvalid,
        # whose message ("Validation failed: ...") must not reach the station.
        raw = [ 2, SecureRandom.uuid, "StartTransaction", { "idTag" => "RFID1" } ].to_json

        MessageHandler.new(@charge_point, raw).process

        frame = last_broadcast_frame
        assert_equal 4, frame[0], "expected a CALLERROR frame"
        assert_equal "InternalError", frame[2]
        refute_match(/Validation failed|Connector|can't be blank/i, frame[3],
          "CALLERROR description must not leak exception messages")
      end

      test "internal errors are logged with a correlation reference sent to the station" do
        raw = [ 2, SecureRandom.uuid, "StartTransaction", { "idTag" => "RFID1" } ].to_json

        log_output = capture_ocpp_log do
          MessageHandler.new(@charge_point, raw).process
        end

        frame = last_broadcast_frame
        error_ref = frame[4]["errorRef"]
        assert error_ref.present?, "CALLERROR details should carry a correlation reference"
        assert_includes log_output, error_ref, "server log should contain the correlation reference"
        assert_includes log_output, "Validation failed", "full exception detail belongs in the server log"
      end

      test "a handler error is reported to Rails.error with the station, action and message id" do
        message_id = SecureRandom.uuid
        raw = [ 2, message_id, "StartTransaction", { "idTag" => "RFID1" } ].to_json

        report = assert_error_reported(ActiveRecord::RecordInvalid) do
          MessageHandler.new(@charge_point, raw).process
        end

        assert_equal "ocpp.rails", report.source
        assert_equal :error, report.severity
        assert_equal @charge_point.identifier, report.context[:charge_point]
        assert_equal "StartTransaction", report.context[:action]
        assert_equal message_id, report.context[:message_id]
        assert_not_includes report.context.to_s, "RFID1", "the payload can hold an id tag and must stay out"
      end

      test "a message that cannot be logged is reported" do
        # A CALL without a message id fails the audit row's validation.
        raw = [ 2, nil, "Heartbeat", {} ].to_json

        report = assert_error_reported(ActiveRecord::RecordInvalid) do
          MessageHandler.new(@charge_point, raw).process
        end

        assert_equal "Heartbeat", report.context[:action]
      end

      test "an unsupported action is answered, not reported" do
        raw = [ 2, SecureRandom.uuid, "NoSuchAction", {} ].to_json

        assert_no_error_reported do
          MessageHandler.new(@charge_point, raw).process
        end

        assert_equal "NotSupported", last_broadcast_frame[2]
      end

      private

      def last_broadcast_frame
        entries = broadcasts(ChargePointChannel.broadcasting_for(@charge_point))
        assert entries.any?, "expected a broadcast to the charge point"
        JSON.parse(JSON.parse(entries.last)["message"])
      end

      def capture_ocpp_log
        io = StringIO.new
        original_broadcasts = ::Rails.logger.broadcasts if ::Rails.logger.respond_to?(:broadcasts)
        capture_logger = ActiveSupport::Logger.new(io)
        ::Rails.logger.broadcast_to(capture_logger)
        yield
        io.string
      ensure
        ::Rails.logger.stop_broadcasting_to(capture_logger) if capture_logger
      end
    end
  end
end
