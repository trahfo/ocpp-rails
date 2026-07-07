module Ocpp
  module Rails
    class ResetJob < ApplicationJob
      queue_as :default

      # type is the OCPP Reset.req ResetType: "Hard" or "Soft".
      def perform(charge_point_id, type)
        charge_point = ChargePoint.find(charge_point_id)
        message_id = SecureRandom.uuid

        payload = {
          type: type
        }

        message = Protocol.build_call(message_id, "Reset", payload)

        Message.create!(
          charge_point: charge_point,
          message_id: message_id,
          direction: "outbound",
          action: "Reset",
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
