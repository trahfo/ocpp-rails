# frozen_string_literal: true

require "test_helper"
require_relative "../support/ocpp_test_helper"

module Ocpp
  module Rails
    # authorizationKey is the station's own Security Profile 1 credential, and
    # every message this server handles is stored with its payload -- so
    # without redaction, setting a station password writes that password into
    # ocpp_messages twice: once as the outbound ChangeConfiguration value, and
    # again when a GetConfiguration reply echoes it back.
    class MessageRedactionTest < ActiveSupport::TestCase
      include OcppTestHelper

      setup { @charge_point = create_charge_point }

      test "an outbound ChangeConfiguration never stores the key in the clear" do
        message = create_message(payload: { "key" => "authorizationKey", "value" => "s3cr3t" })

        assert_equal Message::REDACTED, message.reload.payload["value"]
      end

      test "a GetConfiguration reply is redacted inside its configurationKey array" do
        message = create_message(payload: {
          "response" => { "configurationKey" => [
            { "key" => "HeartbeatInterval", "value" => "300", "readonly" => false },
            { "key" => "authorizationKey", "value" => "s3cr3t", "readonly" => false }
          ] }
        })

        keys = message.reload.payload.dig("response", "configurationKey")

        assert_equal "300", keys.first["value"]
        assert_equal Message::REDACTED, keys.last["value"]
        assert_equal false, keys.last["readonly"], "the rest of the pair is kept"
      end

      test "a station spelling the key differently is redacted too" do
        message = create_message(payload: { "key" => "AuthorizationKey", "value" => "s3cr3t" })

        assert_equal Message::REDACTED, message.reload.payload["value"]
      end

      test "a CALLRESULT merged onto a pending outbound row is redacted as well" do
        message = create_message(payload: { "key" => "authorizationKey", "value" => "s3cr3t" }, status: "pending")

        message.update!(status: "received",
          payload: message.payload.merge(response: { "key" => "authorizationKey", "value" => "s3cr3t" }))

        assert_equal Message::REDACTED, message.reload.payload.dig("response", "value")
      end

      test "another configuration key keeps its value" do
        message = create_message(payload: { "key" => "HeartbeatInterval", "value" => "300" })

        assert_equal "300", message.reload.payload["value"]
      end

      test "a value that merely reads like the key name is kept" do
        message = create_message(payload: { "key" => "ConfigurationKeyList", "value" => "authorizationKey" })

        assert_equal "authorizationKey", message.reload.payload["value"]
      end

      test "a pair carrying no value does not gain one" do
        message = create_message(payload: { "key" => "authorizationKey", "readonly" => false })

        assert_not message.reload.payload.key?("value")
      end

      test "an app that configures no secret keys stores payloads verbatim" do
        with_config(:redacted_configuration_keys, []) do
          message = create_message(payload: { "key" => "authorizationKey", "value" => "s3cr3t" })

          assert_equal "s3cr3t", message.reload.payload["value"]
        end
      end

      private

      def create_message(payload:, status: "sent")
        Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "outbound",
          action: "ChangeConfiguration",
          message_type: "CALL",
          payload: payload,
          status: status
        )
      end

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
