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
    end
  end
end
