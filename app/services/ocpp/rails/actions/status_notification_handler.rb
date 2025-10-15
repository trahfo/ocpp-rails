module Ocpp
  module Rails
    module Actions
      class StatusNotificationHandler
        def initialize(charge_point, message_id, payload)
          @charge_point = charge_point
          @message_id = message_id
          @payload = payload
        end

        def call
          connector_id = @payload['connectorId']
          status = @payload['status']
          error_code = @payload['errorCode']

          ::Rails.logger.info("[OCPP] StatusNotification from #{@charge_point.identifier}: Connector #{connector_id} is #{status}")

          # Update charge point or connector status
          if connector_id == 0
            # Status for entire charge point
            @charge_point.update(status: status)
          else
            # Status for specific connector - store in metadata
            update_connector_status(connector_id, status, error_code)
          end

          # Broadcast status change for real-time UI updates
          broadcast_status_change

          # Return empty response (StatusNotification doesn't require data in response)
          {}
        end

        private

        def update_connector_status(connector_id, status, error_code)
          metadata = @charge_point.metadata || {}
          metadata["connector_#{connector_id}_status"] = status
          metadata["connector_#{connector_id}_error_code"] = error_code if error_code
          metadata["connector_#{connector_id}_updated_at"] = Time.current.iso8601
          @charge_point.update(metadata: metadata)
        end

        def broadcast_status_change
          ActionCable.server.broadcast(
            "charge_point_#{@charge_point.id}_status",
            {
              connector_id: @payload['connectorId'],
              status: @payload['status'],
              error_code: @payload['errorCode'],
              info: @payload['info'],
              vendor_id: @payload['vendorId'],
              vendor_error_code: @payload['vendorErrorCode'],
              timestamp: @payload['timestamp'] || Time.current.iso8601
            }
          )
        rescue => e
          ::Rails.logger.error("[OCPP] Failed to broadcast status change: #{e.message}")
        end
      end
    end
  end
end
