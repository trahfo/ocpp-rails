require "test_helper"
require_relative "../../support/ocpp_test_helper"

module Ocpp
  module Rails
    module RawSocket
      # The handshake decides accept/reject purely from the Rack env, so it is
      # tested with plain env hashes — no sockets. It must authenticate a station
      # exactly as ChargePointChannel#subscribed does (rate limit, then
      # StationAuthenticator), differing only in reading the identity from the
      # URL path rather than a subscribe command.
      class HandshakeTest < ActiveSupport::TestCase
        include OcppTestHelper

        setup do
          @charge_point = create_charge_point(identifier: "CP-RAW-1", auth_password: "station-secret")
        end

        def env(path:, password: "station-secret", identifier: "CP-RAW-1", protocol: "ocpp1.6", auth: :basic)
          e = { "PATH_INFO" => path }
          e["HTTP_SEC_WEBSOCKET_PROTOCOL"] = protocol if protocol
          if auth == :basic
            e["HTTP_AUTHORIZATION"] = "Basic " + Base64.strict_encode64("#{identifier}:#{password}")
          end
          e
        end

        test "identifier_from_path takes the last non-empty, URL-decoded segment" do
          assert_equal "CP-1", Handshake.identifier_from_path("/CP-1")
          assert_equal "CP-1", Handshake.identifier_from_path("/ocpp/CP-1")
          assert_equal "CP-1", Handshake.identifier_from_path("/ocpp/steve/CP-1")
          assert_equal "CP 1", Handshake.identifier_from_path("/ocpp/CP%201")
          assert_nil Handshake.identifier_from_path("/")
          assert_nil Handshake.identifier_from_path(nil)
        end

        test "accepts a station presenting a valid identity and credential" do
          result = Handshake.new(env(path: "/ocpp/CP-RAW-1")).call

          assert result.accepted?
          assert_equal @charge_point, result.charge_point
          assert_equal "CP-RAW-1", result.identifier
          assert_equal "ocpp1.6", result.subprotocol
        end

        test "rejects an unknown identifier" do
          result = Handshake.new(env(path: "/ocpp/CP-NOPE", identifier: "CP-NOPE")).call

          assert_not result.accepted?
          assert_equal :unknown_charge_point, result.failure
        end

        test "rejects a wrong password" do
          result = Handshake.new(env(path: "/ocpp/CP-RAW-1", password: "wrong")).call

          assert_not result.accepted?
          assert_equal :invalid_credentials, result.failure
        end

        test "rejects a missing Authorization header under basic auth" do
          result = Handshake.new(env(path: "/ocpp/CP-RAW-1", auth: :none)).call

          assert_not result.accepted?
          assert_equal :missing_credentials, result.failure
        end

        test "rejects a request with no identifier in the path" do
          result = Handshake.new(env(path: "/")).call

          assert_not result.accepted?
          assert_equal :missing_identifier, result.failure
        end

        test "rejects once the per-station connection rate limit is exhausted" do
          limit = Ocpp::Rails.configuration.max_connection_attempts_per_minute
          limit.times { assert Ocpp::Rails.connection_rate_limiter.allow?("CP-RAW-1") }

          result = Handshake.new(env(path: "/ocpp/CP-RAW-1")).call

          assert_not result.accepted?
          assert_equal :rate_limited, result.failure
        end

        test "negotiates no subprotocol when the station offers none we support" do
          result = Handshake.new(env(path: "/ocpp/CP-RAW-1", protocol: "ocpp2.0.1")).call

          assert result.accepted?, "auth still succeeds; only the subprotocol is unmatched"
          assert_nil result.subprotocol
        end

        test "in :none auth mode an existing station connects without credentials" do
          original = Ocpp::Rails.configuration.authentication_mode
          Ocpp::Rails.configuration.authentication_mode = :none

          result = Handshake.new(env(path: "/ocpp/CP-RAW-1", auth: :none)).call

          assert result.accepted?
          assert_equal @charge_point, result.charge_point
        ensure
          Ocpp::Rails.configuration.authentication_mode = original
        end
      end
    end
  end
end
