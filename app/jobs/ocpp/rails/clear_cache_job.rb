module Ocpp
  module Rails
    class ClearCacheJob < ApplicationJob
      queue_as :default

      def perform(charge_point_id)
        charge_point = ChargePoint.find(charge_point_id)
        message_id = SecureRandom.uuid

        # ClearCache.req carries no fields.
        payload = {}

        message = Protocol.build_call(message_id, "ClearCache", payload)

        Message.create!(
          charge_point: charge_point,
          message_id: message_id,
          direction: "outbound",
          action: "ClearCache",
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
