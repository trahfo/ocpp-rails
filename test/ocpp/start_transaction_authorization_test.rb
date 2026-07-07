# frozen_string_literal: true

require "test_helper"
require_relative "../support/ocpp_test_helper"

module Ocpp
  module Rails
    class StartTransactionAuthorizationTest < ActiveSupport::TestCase
      include OcppTestHelper

      class TagListHook
        def call(_charge_point_id, id_tag)
          case id_tag
          when "BLOCKED_TAG" then { status: "Blocked" }
          when "EXPIRED_TAG" then { status: "Expired" }
          else { status: "Accepted" }
          end
        end
      end

      setup do
        @charge_point = create_charge_point
        @original_hooks = Ocpp::Rails.configuration.authorization_hooks.dup
        Ocpp::Rails.configuration.authorization_hooks << TagListHook.new
      end

      teardown do
        Ocpp::Rails.configuration.authorization_hooks.replace(@original_hooks)
      end

      test "blocked idTag does not open a transaction" do
        response = nil
        assert_no_difference "Ocpp::Rails::ChargingSession.count" do
          response = start_transaction(id_tag: "BLOCKED_TAG")
        end

        assert_equal "Blocked", response["idTagInfo"]["status"]
      end

      test "expired idTag does not open a transaction" do
        response = nil
        assert_no_difference "Ocpp::Rails::ChargingSession.count" do
          response = start_transaction(id_tag: "EXPIRED_TAG")
        end

        assert_equal "Expired", response["idTagInfo"]["status"]
      end

      test "accepted idTag starts the session as before" do
        response = nil
        assert_difference "Ocpp::Rails::ChargingSession.count", 1 do
          response = start_transaction(id_tag: "GOOD_TAG")
        end

        assert_equal "Accepted", response["idTagInfo"]["status"]
        assert_equal response["transactionId"], @charge_point.charging_sessions.last.transaction_id
      end

      test "the authorization decision is persisted for audit" do
        assert_difference "Ocpp::Rails::Authorization.count", 1 do
          start_transaction(id_tag: "BLOCKED_TAG")
        end

        authorization = Authorization.last
        assert_equal "Blocked", authorization.status
        assert_equal "BLOCKED_TAG", authorization.id_tag
      end

      private

      def start_transaction(id_tag:)
        Actions::StartTransactionHandler.new(@charge_point, SecureRandom.uuid, {
          "connectorId" => 1,
          "idTag" => id_tag,
          "meterStart" => 0,
          "timestamp" => Time.current.iso8601
        }).call
      end
    end
  end
end
