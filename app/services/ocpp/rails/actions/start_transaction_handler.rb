module Ocpp
  module Rails
    module Actions
      class StartTransactionHandler
        def initialize(charge_point, message_id, payload)
          @charge_point = charge_point
          @message_id = message_id
          @payload = payload
        end

        def call
          # Create new charging session
          session = @charge_point.charging_sessions.create!(
            connector_id: @payload['connectorId'],
            id_tag: @payload['idTag'],
            start_meter_value: @payload['meterStart'],
            started_at: parse_timestamp(@payload['timestamp']),
            status: 'Charging'
          )

          ::Rails.logger.info("[OCPP] StartTransaction from #{@charge_point.identifier}: Connector #{@payload['connectorId']}, Transaction ID: #{session.id}")

          # Update charge point status
          @charge_point.update(status: 'Charging')

          # Broadcast session started event for real-time UI updates
          broadcast_session_started(session)

          # Return transaction ID and authorization status
          {
            'idTagInfo' => {
              'status' => 'Accepted'
            },
            'transactionId' => session.id
          }
        end

        private

        def parse_timestamp(timestamp_string)
          Time.parse(timestamp_string)
        rescue ArgumentError, TypeError
          Time.current
        end

        def broadcast_session_started(session)
          ActionCable.server.broadcast(
            "charge_point_#{@charge_point.id}_sessions",
            {
              event: 'started',
              session: {
                id: session.id,
                connector_id: session.connector_id,
                id_tag: session.id_tag,
                started_at: session.started_at.iso8601,
                start_meter_value: session.start_meter_value
              }
            }
          )
        rescue => e
          ::Rails.logger.error("[OCPP] Failed to broadcast session started: #{e.message}")
        end
      end
    end
  end
end
