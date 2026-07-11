# frozen_string_literal: true

require "test_helper"
require_relative "../support/ocpp_test_helper"

module Ocpp
  module Rails
    # Upgrade path from the pre-0.3.0 metadata convention
    # (connector_<n>_status / _error_code / _updated_at keys) to the
    # ocpp_connector_statuses table.
    class ConnectorStatusBackfillTest < ActiveSupport::TestCase
      include OcppTestHelper

      test "copies legacy metadata keys into connector statuses and strips them" do
        cp = create_charge_point(metadata: {
          "connector_1_status" => "Charging",
          "connector_1_error_code" => "NoError",
          "connector_1_updated_at" => "2026-07-01T00:00:00Z",
          "connector_2_status" => "Faulted",
          "connector_2_error_code" => "GroundFailure",
          "custom_key" => "kept"
        })

        ConnectorStatusBackfill.run

        cp.reload
        assert_equal "Charging", cp.connector_status(1)
        assert_equal "Faulted", cp.connector_status(2)
        assert_equal "GroundFailure", cp.connector_error_code(2)
        assert_equal({ "custom_key" => "kept" }, cp.metadata)
      end

      test "keeps an existing connector status row over legacy metadata" do
        cp = create_charge_point(metadata: { "connector_1_status" => "Charging" })
        cp.connector_statuses.create!(connector_id: 1, status: "Available")

        ConnectorStatusBackfill.run

        cp.reload
        assert_equal "Available", cp.connector_status(1),
          "a row written since the upgrade is fresher than legacy metadata"
        assert_equal({}, cp.metadata)
      end

      test "leaves charge points without legacy keys untouched" do
        cp = create_charge_point(metadata: { "note" => "hi" })

        ConnectorStatusBackfill.run

        cp.reload
        assert_equal({ "note" => "hi" }, cp.metadata)
        assert_empty cp.connector_statuses
      end
    end
  end
end
