module Ocpp
  module Rails
    class ChargePointChannel < ActionCable::Channel::Base
      # Charge point subscribes with their identifier
      def subscribed
        charge_point_id = params[:charge_point_id]
        @charge_point = ChargePoint.find_by(identifier: charge_point_id)

        if @charge_point
          stream_for @charge_point
          @charge_point.update(connected: true, last_heartbeat_at: Time.current)
          logger.info "ChargePoint #{charge_point_id} connected"
        else
          reject
          logger.warn "ChargePoint #{charge_point_id} not found, connection rejected"
        end
      end

      def unsubscribed
        if @charge_point
          @charge_point.disconnect!
          logger.info "ChargePoint #{@charge_point.identifier} disconnected"
        end
      end

      # Receive OCPP messages from charge point
      def receive(data)
        return unless @charge_point

        message = data["message"]
        MessageHandler.new(@charge_point, message).process
      rescue => e
        logger.error "Error receiving message from ChargePoint #{@charge_point&.identifier}: #{e.message}"
        logger.error e.backtrace.join("\n")
      end
    end
  end
end
