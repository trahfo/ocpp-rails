# frozen_string_literal: true

require "test_helper"
require_relative "../support/ocpp_test_helper"

module Ocpp
  module Rails
    class StationAuthenticatorTest < ActiveSupport::TestCase
      include OcppTestHelper

      setup do
        @charge_point = create_charge_point(identifier: "CP001", auth_password: "station-secret")
      end

      test "valid credentials authenticate the charge point" do
        result = StationAuthenticator.authenticate(
          identifier: "CP001",
          authorization_header: basic_auth_header("CP001", "station-secret")
        )

        assert result.success?
        assert_equal @charge_point, result.charge_point
      end

      test "wrong password is rejected" do
        result = StationAuthenticator.authenticate(
          identifier: "CP001",
          authorization_header: basic_auth_header("CP001", "wrong")
        )

        assert_not result.success?
      end

      test "credentials of station X cannot authenticate as station Y" do
        create_charge_point(identifier: "CP002", auth_password: "other-secret")

        result = StationAuthenticator.authenticate(
          identifier: "CP001",
          authorization_header: basic_auth_header("CP002", "other-secret")
        )

        assert_not result.success?
      end

      test "missing Authorization header is rejected" do
        result = StationAuthenticator.authenticate(identifier: "CP001", authorization_header: nil)

        assert_not result.success?
      end

      test "station without a configured credential is rejected in basic mode" do
        create_charge_point(identifier: "CP_NOCRED")

        result = StationAuthenticator.authenticate(
          identifier: "CP_NOCRED",
          authorization_header: basic_auth_header("CP_NOCRED", "anything")
        )

        assert_not result.success?
      end

      test "unknown identifier is rejected" do
        result = StationAuthenticator.authenticate(
          identifier: "GHOST",
          authorization_header: basic_auth_header("GHOST", "x")
        )

        assert_not result.success?
      end

      test "authentication_mode :none accepts a known station without credentials" do
        with_authentication_mode(:none) do
          result = StationAuthenticator.authenticate(identifier: "CP001", authorization_header: nil)

          assert result.success?
        end
      end

      test "authentication defaults to basic mode" do
        assert_equal :basic, Configuration.new.authentication_mode
      end

      test "password digests are stored hashed, never plaintext" do
        assert_not_includes @charge_point.auth_password_digest, "station-secret"
        assert @charge_point.authenticate_password?("station-secret")
        assert_not @charge_point.authenticate_password?("station-secre")
        assert_not @charge_point.authenticate_password?(nil)
      end

      private

      def basic_auth_header(username, password)
        "Basic #{Base64.strict_encode64("#{username}:#{password}")}"
      end

      def with_authentication_mode(mode)
        original = Ocpp::Rails.configuration.authentication_mode
        Ocpp::Rails.configuration.authentication_mode = mode
        yield
      ensure
        Ocpp::Rails.configuration.authentication_mode = original
      end
    end

    class ChannelAuthenticationTest < ActionCable::Channel::TestCase
      tests Ocpp::Rails::ChargePointChannel
      include OcppTestHelper

      setup do
        @charge_point = create_charge_point(identifier: "CP001", auth_password: "station-secret")
      end

      test "subscription with valid Basic credentials is accepted" do
        stub_connection(request: request_with_auth("CP001", "station-secret"))

        subscribe charge_point_id: "CP001"

        assert subscription.confirmed?
        assert_has_stream_for @charge_point
      end

      test "subscription without credentials is rejected before streaming" do
        subscribe charge_point_id: "CP001"

        assert subscription.rejected?
      end

      test "subscription with wrong credentials is rejected" do
        stub_connection(request: request_with_auth("CP001", "wrong"))

        subscribe charge_point_id: "CP001"

        assert subscription.rejected?
      end

      test "credentials for one identifier cannot subscribe as another" do
        create_charge_point(identifier: "CP002", auth_password: "other-secret")
        stub_connection(request: request_with_auth("CP002", "other-secret"))

        subscribe charge_point_id: "CP001"

        assert subscription.rejected?
      end

      # OCTT TC_085 (Basic Authentication valid) plus the post-connect boot sequence:
      # once a station is authenticated and streaming, BootNotification is accepted
      # and a per-connector StatusNotification is acknowledged.
      test "a station with valid credentials completes registration then boot proceeds" do
        stub_connection(request: request_with_auth("CP001", "station-secret"))

        subscribe charge_point_id: "CP001"

        assert subscription.confirmed?
        assert_has_stream_for @charge_point

        resp = Actions::BootNotificationHandler.new(
          @charge_point, SecureRandom.uuid, build_boot_notification_request.stringify_keys
        ).call
        assert_equal "Accepted", resp["status"]

        assert_equal({}, Actions::StatusNotificationHandler.new(
          @charge_point, SecureRandom.uuid, { "connectorId" => 1, "status" => "Available", "errorCode" => "NoError" }
        ).call)
      end

      private

      def request_with_auth(username, password)
        ActionDispatch::TestRequest.create(
          "HTTP_AUTHORIZATION" => "Basic #{Base64.strict_encode64("#{username}:#{password}")}"
        )
      end
    end
  end
end
