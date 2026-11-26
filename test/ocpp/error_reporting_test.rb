# frozen_string_literal: true

require "test_helper"

module Ocpp
  module Rails
    class ErrorReportingTest < ActiveSupport::TestCase
      test "a rescued fault is reported as a handled error from the gem's own source" do
        report = assert_error_reported(ArgumentError) do
          ErrorReporting.report(ArgumentError.new("boom"), charge_point: "CP-1", action: "Heartbeat", message_id: "m1")
        end

        assert report.handled?
        assert_equal :error, report.severity, "handled: true alone would make it a warning"
        assert_equal "ocpp.rails", report.source
        assert_equal "CP-1", report.context[:charge_point]
        assert_equal "Heartbeat", report.context[:action]
        assert_equal "m1", report.context[:message_id]
      end

      test "context it does not know is left out rather than reported as nil" do
        report = assert_error_reported(ArgumentError) do
          ErrorReporting.report(ArgumentError.new("boom"), charge_point: "CP-1")
        end

        assert_not report.context.key?(:action)
        assert_not report.context.key?(:message_id)
      end

      test "a malformed frame cannot smuggle a payload into the context" do
        report = assert_error_reported(ArgumentError) do
          ErrorReporting.report(ArgumentError.new("boom"),
            charge_point: "CP-1", action: { "idTag" => "RFID1" }, message_id: "m" * 500)
        end

        assert_not report.context.key?(:action), "only a string is an action"
        assert_equal 100, report.context[:message_id].length
      end

      test "a reporter that raises does not reach the caller" do
        # Rails.error.report raises ArgumentError for anything but an Exception.
        assert_nothing_raised { ErrorReporting.report("not an exception", charge_point: "CP-1") }
      end
    end
  end
end
