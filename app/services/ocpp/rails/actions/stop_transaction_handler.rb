module Ocpp
  module Rails
    module Actions
      class StopTransactionHandler
        def initialize(charge_point, message_id, payload)
          @charge_point = charge_point
          @message_id = message_id
          @payload = payload
        end

        def call
          # Find the session by transaction ID
          session = @charge_point.charging_sessions.find_by(id: @payload['transactionId'])

          unless session
            ::Rails.logger.error("[OCPP] StopTransaction: Session not found for transaction ID #{@payload['transactionId']}")
            return {
              'idTagInfo' => {
                'status' => 'Invalid'
              }
            }
          end

          # Stop the session
          session.stop!(
            reason: @payload['reason'] || 'Local',
            meter_value: @payload['meterStop']
          )

          ::Rails.logger.info("[OCPP] StopTransaction from #{@charge_point.identifier}: Transaction ID #{session.id}, Energy: #{session.energy_consumed} Wh")

          # Process transaction data (meter values during charging) if provided
          if @payload['transactionData']
            process_transaction_data(session, @payload['transactionData'])
          end

          # Update charge point status if no other active sessions
          if @charge_point.charging_sessions.active.empty?
            @charge_point.update(status: 'Available')
          end

          # Broadcast session stopped event for real-time UI updates
          broadcast_session_stopped(session)

          # Return authorization status
          {
            'idTagInfo' => {
              'status' => 'Accepted'
            }
          }
        end

        private

        def process_transaction_data(session, transaction_data)
          transaction_data.each do |meter_values_set|
            timestamp = parse_timestamp(meter_values_set['timestamp'])

            sampled_values = meter_values_set['sampledValue'] || []
            sampled_values.each do |sampled_value|
              create_meter_value(session, timestamp, sampled_value)
            end
          end
        rescue => e
          ::Rails.logger.error("[OCPP] Error processing transaction data: #{e.message}")
        end

        def create_meter_value(session, timestamp, sampled_value)
          session.meter_values.create!(
            charge_point: @charge_point,
            connector_id: session.connector_id,
            measurand: sampled_value['measurand'] || 'Energy.Active.Import.Register',
            phase: sampled_value['phase'],
            unit: sampled_value['unit'] || 'Wh',
            context: sampled_value['context'] || 'Transaction.End',
            format: sampled_value['format'] || 'Raw',
            location: sampled_value['location'] || 'Outlet',
            value: sampled_value['value'],
            timestamp: timestamp
          )
        end

        def parse_timestamp(timestamp_string)
          Time.parse(timestamp_string)
        rescue ArgumentError, TypeError
          Time.current
        end

        def broadcast_session_stopped(session)
          ActionCable.server.broadcast(
            "charge_point_#{@charge_point.id}_sessions",
            {
              event: 'stopped',
              session: {
                id: session.id,
                connector_id: session.connector_id,
                stopped_at: session.stopped_at.iso8601,
                energy_consumed: session.energy_consumed,
                duration_seconds: session.duration_seconds,
                stop_reason: session.stop_reason
              }
            }
          )
        rescue => e
          ::Rails.logger.error("[OCPP] Failed to broadcast session stopped: #{e.message}")
        end
      end
    end
  end
end
