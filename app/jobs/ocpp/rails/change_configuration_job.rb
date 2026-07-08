module Ocpp
  module Rails
    class ChangeConfigurationJob < ApplicationJob
      queue_as :default

      # key/value are the OCPP ChangeConfiguration.req fields; value is always a
      # string, even for numeric configuration keys.
      def perform(charge_point_id, key, value)
        charge_point = ChargePoint.find(charge_point_id)
        message_id = SecureRandom.uuid

        payload = {
          key: key,
          value: value
        }

        message = Protocol.build_call(message_id, "ChangeConfiguration", payload)

        Message.create!(
          charge_point: charge_point,
          message_id: message_id,
          direction: "outbound",
          action: "ChangeConfiguration",
          message_type: "CALL",
          payload: payload,
          status: "pending"
        )

        send_to_charge_point(charge_point, message)
      end

      private

      def send_to_charge_point(charge_point, message)
        # stream_for in ChargePointChannel relays this straight down the
        # station's WebSocket, the same path CALLRESULTs already use.
        ChargePointChannel.broadcast_to(charge_point, { message: message })
      end
    end
  end
end
