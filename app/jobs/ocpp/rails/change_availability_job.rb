module Ocpp
  module Rails
    class ChangeAvailabilityJob < ApplicationJob
      queue_as :default

      # connector_id/type are the OCPP ChangeAvailability.req fields; type is
      # "Operative" or "Inoperative", and connectorId 0 targets the whole charge
      # point rather than a single connector.
      def perform(charge_point_id, connector_id, type)
        charge_point = ChargePoint.find(charge_point_id)
        message_id = SecureRandom.uuid

        payload = {
          connectorId: connector_id.to_i,
          type: type
        }

        message = Protocol.build_call(message_id, "ChangeAvailability", payload)

        Message.create!(
          charge_point: charge_point,
          message_id: message_id,
          direction: "outbound",
          action: "ChangeAvailability",
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
