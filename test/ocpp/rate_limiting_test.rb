# frozen_string_literal: true

require "test_helper"
require_relative "../support/ocpp_test_helper"

module Ocpp
  module Rails
    class RateLimiterTest < ActiveSupport::TestCase
      test "allows events under the limit and blocks events over it" do
        limiter = RateLimiter.new { 3 }

        assert_equal [ true, true, true, false, false ],
          5.times.map { limiter.allow?("CP1") }
      end

      test "keys are throttled independently" do
        limiter = RateLimiter.new { 1 }

        assert limiter.allow?("CP1")
        assert limiter.allow?("CP2")
        assert_not limiter.allow?("CP1")
      end

      test "a new window resets the budget" do
        limiter = RateLimiter.new(window: 60) { 1 }

        assert limiter.allow?("CP1", now: 0)
        assert_not limiter.allow?("CP1", now: 30)
        assert limiter.allow?("CP1", now: 61)
      end

      test "a nil limit disables throttling" do
        limiter = RateLimiter.new { nil }

        assert(100.times.all? { limiter.allow?("CP1") })
      end
    end

    class ChannelRateLimitTest < ActionCable::Channel::TestCase
      tests Ocpp::Rails::ChargePointChannel
      include OcppTestHelper

      PASSWORD = "station-secret"

      setup do
        @charge_point = create_charge_point(auth_password: PASSWORD)
        stub_connection(request: ActionDispatch::TestRequest.create(
          "HTTP_AUTHORIZATION" => "Basic #{Base64.strict_encode64("#{@charge_point.identifier}:#{PASSWORD}")}"
        ))
      end

      test "a station exceeding the message rate is throttled without unbounded DB writes" do
        with_config(:max_messages_per_minute, 3) do
          subscribe charge_point_id: @charge_point.identifier

          5.times do
            perform :receive, "message" => [ 2, SecureRandom.uuid, "Heartbeat", {} ].to_json
          end

          inbound = @charge_point.messages.where(direction: "inbound").count
          assert_equal 3, inbound, "messages beyond the limit must not be processed or logged"
        end
      end

      test "message throttling is disabled when the limit is nil" do
        with_config(:max_messages_per_minute, nil) do
          subscribe charge_point_id: @charge_point.identifier

          5.times do
            perform :receive, "message" => [ 2, SecureRandom.uuid, "Heartbeat", {} ].to_json
          end

          assert_equal 5, @charge_point.messages.where(direction: "inbound").count
        end
      end

      test "connection attempts beyond the limit are rejected even with valid credentials" do
        with_config(:max_connection_attempts_per_minute, 2) do
          2.times do
            subscribe charge_point_id: @charge_point.identifier
            assert subscription.confirmed?
            unsubscribe
          end

          subscribe charge_point_id: @charge_point.identifier
          assert subscription.rejected?
        end
      end

      private

      def with_config(key, value)
        original = Ocpp::Rails.configuration.public_send(key)
        Ocpp::Rails.configuration.public_send("#{key}=", value)
        yield
      ensure
        Ocpp::Rails.configuration.public_send("#{key}=", original)
      end
    end
  end
end
