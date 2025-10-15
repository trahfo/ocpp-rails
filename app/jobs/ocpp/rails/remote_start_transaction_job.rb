module Ocpp
  module Rails
    class RemoteStartTransactionJob < ApplicationJob
      queue_as :default

      def perform(charge_point_id, connector_id, id_tag)
        charge_point = ChargePoint.find(charge_point_id)
        message_id = SecureRandom.uuid

        payload = {
          connectorId: connector_id.to_i,
          idTag: id_tag
        }

        message = Protocol::MessageHandler.build_call(message_id, "RemoteStartTransaction", payload)

        Message.create!(
          charge_point: charge_point,
          message_id: message_id,
          direction: "outbound",
          action: "RemoteStartTransaction",
          message_type: "CALL",
          payload: payload,
          status: "pending"
        )

        send_to_charge_point(charge_point, message)
      end

      private

      def send_to_charge_point(charge_point, message)
        ActionCable.server.broadcast(
          "charge_point_#{charge_point.id}_outbound",
          { message: message }
        )
      end
    end
  end
end
