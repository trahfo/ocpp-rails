module Ocpp
  module Rails
    class ChargePointChannel < ActionCable::Channel::Base
      # Charge point subscribes with their identifier
      def subscribed
        charge_point_id = params[:charge_point_id]
        @charge_point = ChargePoint.find_by(identifier: charge_point_id)

        if @charge_point
          stream_for @charge_point
          old_connected = @charge_point.connected
          @charge_point.update(connected: true, last_heartbeat_at: Time.current)
          logger.info "ChargePoint #{charge_point_id} connected"
          
          # Log connection state change if it actually changed
          log_connection_change(old_connected, true, "subscribed")
        else
          reject
          logger.warn "ChargePoint #{charge_point_id} not found, connection rejected"
        end
      end

      def unsubscribed
        if @charge_point
          old_connected = @charge_point.connected
          @charge_point.disconnect!
          logger.info "ChargePoint #{@charge_point.identifier} disconnected"
          
          # Log connection state change if it actually changed
          log_connection_change(old_connected, false, "unsubscribed")
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

      private

      def log_connection_change(old_connected, new_connected, source)
        return if old_connected == new_connected
        
        begin
          Ocpp::Rails::StateChange.create!(
            charge_point: @charge_point,
            change_type: "connection",
            connector_id: nil,
            old_value: old_connected.to_s,
            new_value: new_connected.to_s,
            metadata: { source: source }
          )
        rescue => error
          logger.error("Failed to log state change: #{error.message}")
        end
      end
    end
  end
end
