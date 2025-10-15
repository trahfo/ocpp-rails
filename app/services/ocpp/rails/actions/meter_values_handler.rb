module Ocpp
  module Rails
    module Actions
      class MeterValuesHandler
        def initialize(charge_point, message_id, payload)
          @charge_point = charge_point
          @message_id = message_id
          @payload = payload
        end

        def call
          connector_id = @payload['connectorId']
          transaction_id = @payload['transactionId']

          # Find active session if transaction ID provided
          session = if transaction_id
            @charge_point.charging_sessions.find_by(id: transaction_id)
          else
            @charge_point.charging_sessions.active.find_by(connector_id: connector_id)
          end

          # Process each meter value set
          meter_value_sets = @payload['meterValue'] || []
          meter_value_sets.each do |meter_value_set|
            timestamp = parse_timestamp(meter_value_set['timestamp'])

            sampled_values = meter_value_set['sampledValue'] || []
            sampled_values.each do |sampled_value|
              meter_value = create_meter_value(session, connector_id, timestamp, sampled_value)
              broadcast_meter_value(meter_value) if meter_value
            end
          end

          ::Rails.logger.debug("[OCPP] MeterValues from #{@charge_point.identifier}: Connector #{connector_id}, #{meter_value_sets.size} value sets")

          # Return empty response (MeterValues doesn't require data in response)
          {}
        end

        private

        def create_meter_value(session, connector_id, timestamp, sampled_value)
          @charge_point.meter_values.create!(
            charging_session: session,
            connector_id: connector_id,
            measurand: sampled_value['measurand'] || 'Energy.Active.Import.Register',
            phase: sampled_value['phase'],
            unit: sampled_value['unit'] || 'Wh',
            context: sampled_value['context'] || 'Sample.Periodic',
            format: sampled_value['format'] || 'Raw',
            location: sampled_value['location'] || 'Outlet',
            value: sampled_value['value'],
            timestamp: timestamp
          )
        rescue => e
          ::Rails.logger.error("[OCPP] Failed to create meter value: #{e.message}")
          nil
        end

        def parse_timestamp(timestamp_string)
          Time.parse(timestamp_string)
        rescue ArgumentError, TypeError
          Time.current
        end

        def broadcast_meter_value(meter_value)
          ActionCable.server.broadcast(
            "charge_point_#{@charge_point.id}_meter_values",
            {
              connector_id: meter_value.connector_id,
              measurand: meter_value.measurand,
              value: meter_value.value.to_f,
              unit: meter_value.unit,
              phase: meter_value.phase,
              context: meter_value.context,
              timestamp: meter_value.timestamp.iso8601,
              session_id: meter_value.charging_session_id
            }
          )
        rescue => e
          ::Rails.logger.error("[OCPP] Failed to broadcast meter value: #{e.message}")
        end
      end
    end
  end
end
