module Ocpp
  module Rails
    class GetConfigurationJob < ApplicationJob
      queue_as :default

      # keys is the OCPP GetConfiguration.req optional key array; when blank the
      # station returns every configuration key.
      def perform(charge_point_id, keys = [])
        charge_point = ChargePoint.find(charge_point_id)
        message_id = SecureRandom.uuid

        payload = keys.blank? ? {} : { key: Array(keys) }

        message = Protocol.build_call(message_id, "GetConfiguration", payload)

        Message.create!(
          charge_point: charge_point,
          message_id: message_id,
          direction: "outbound",
          action: "GetConfiguration",
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
