# frozen_string_literal: true

require "test_helper"
require_relative "../support/ocpp_test_helper"

module Ocpp
  module Rails
    class ConfigurationTest < ActiveSupport::TestCase
      include OcppTestHelper

      test "default supported_versions only advertises implemented versions" do
        assert_equal [ "1.6" ], Configuration.new.supported_versions
      end

      test "charge point with unimplemented protocol version is rejected" do
        charge_point = ChargePoint.new(identifier: "CP_V2", ocpp_protocol: "2.1")

        assert_not charge_point.valid?
        assert_includes charge_point.errors[:ocpp_protocol], "is not included in the list"
      end

      test "charge point with 1.6 protocol is accepted" do
        assert create_charge_point(ocpp_protocol: "1.6").persisted?
      end

      test "session hooks default to empty and register like the other hook types" do
        config = Configuration.new
        assert_equal [], config.session_hooks

        hook = ->(session, event) { }
        config.register_session_hook(hook)
        assert_equal [ hook ], config.session_hooks
      end

      test "registering a session hook that does not respond to call raises" do
        assert_raises(ArgumentError) do
          Configuration.new.register_session_hook(Object.new)
        end
      end
    end
  end
end
