module Ocpp
  module Rails
    class ChargePointChannel < ActionCable::Channel::Base
      # Charge point subscribes with their identifier; the credential travels
      # in the HTTP Basic Authorization header of the WebSocket upgrade
      # (OCPP-J Security Profile 1).
      def subscribed
        charge_point_id = params[:charge_point_id]

        unless Ocpp::Rails.connection_rate_limiter.allow?(charge_point_id.to_s)
          reject
          logger.warn "[OCPP][security] ChargePoint #{charge_point_id} subscription rejected: connection rate limit exceeded"
          return
        end

        result = StationAuthenticator.authenticate(
          identifier: charge_point_id,
          authorization_header: authorization_header
        )

        unless result.success?
          reject
          logger.warn "[OCPP][security] ChargePoint #{charge_point_id} subscription rejected: #{result.failure}"
          return
        end

        @charge_point = result.charge_point
        stream_for @charge_point
        old_connected = @charge_point.connected
        @charge_point.update(connected: true, last_heartbeat_at: Time.current)
        logger.info "ChargePoint #{charge_point_id} connected"

        # Log connection state change if it actually changed
        log_connection_change(old_connected, true, "subscribed")
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

        # Drop before any processing or Message-row write, so a chatty or
        # malicious station cannot grow the database unboundedly.
        unless Ocpp::Rails.message_rate_limiter.allow?(@charge_point.identifier)
          logger.warn "[OCPP][security] ChargePoint #{@charge_point.identifier}: message rate limit exceeded, dropping message"
          return
        end

        message = data["message"]
        MessageHandler.new(@charge_point, message).process
      rescue => e
        logger.error "Error receiving message from ChargePoint #{@charge_point&.identifier}: #{e.message}"
        logger.error e.backtrace.join("\n")
      end

      private

      # The connection's request is protected API; ConnectionStub in channel
      # tests may not define it at all, and :none mode must keep working then.
      def authorization_header
        return nil unless connection.respond_to?(:request, true)

        connection.send(:request).headers["Authorization"]
      end

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
