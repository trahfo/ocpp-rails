# frozen_string_literal: true

require "test_helper"
require_relative "../support/ocpp_test_helper"

module Ocpp
  module Rails
    class AuthorizeHandlerTest < ActiveSupport::TestCase
      include OcppTestHelper

      # Sync authorization hook that maps known idTags to fixed OCPP statuses,
      # letting each test drive the handler to a specific decision.
      class TagHook
        def call(_charge_point_id, id_tag)
          case id_tag
          when "INVALID_TAG" then { status: "Invalid" }
          when "EXPIRED_TAG" then { status: "Expired" }
          when "BLOCKED_TAG" then { status: "Blocked" }
          else { status: "Accepted", expiry_date: Time.current + 1.year }
          end
        end
      end

      setup do
        @cp = create_charge_point
        @original_hooks = Ocpp::Rails.configuration.authorization_hooks.dup
        Ocpp::Rails.configuration.authorization_hooks << TagHook.new
      end

      teardown do
        Ocpp::Rails.configuration.authorization_hooks.replace(@original_hooks)
      end

      # TC_023_1: an invalid idTag is rejected with status "Invalid".
      test "invalid idTag is authorized as Invalid" do
        response = authorize("INVALID_TAG")

        assert_equal "Invalid", response["idTagInfo"]["status"]
      end

      # TC_023_2: an expired idTag is rejected with status "Expired".
      test "expired idTag is authorized as Expired" do
        response = authorize("EXPIRED_TAG")

        assert_equal "Expired", response["idTagInfo"]["status"]
      end

      # TC_023_3: a blocked idTag is rejected with status "Blocked".
      test "blocked idTag is authorized as Blocked" do
        response = authorize("BLOCKED_TAG")

        assert_equal "Blocked", response["idTagInfo"]["status"]
      end

      # Happy path: an accepted idTag returns "Accepted" with a parseable expiry.
      test "accepted idTag is authorized with an expiry date" do
        response = authorize("GOOD_TAG")

        assert_equal "Accepted", response["idTagInfo"]["status"]

        expiry = response["idTagInfo"]["expiryDate"]
        assert expiry.present?, "expected an expiryDate on an accepted authorization"
        assert_nothing_raised { Time.iso8601(expiry) }
      end

      # The authorization decision is persisted for audit, recording both the
      # rejected status and the presented idTag.
      test "the authorization decision is persisted for audit" do
        assert_difference "Ocpp::Rails::Authorization.count", 1 do
          authorize("BLOCKED_TAG")
        end

        authorization = Authorization.last
        assert_equal "Blocked", authorization.status
        assert_equal "BLOCKED_TAG", authorization.id_tag
      end

      private

      def authorize(tag)
        Actions::AuthorizeHandler.new(@cp, SecureRandom.uuid, { "idTag" => tag }).call
      end
    end
  end
end
