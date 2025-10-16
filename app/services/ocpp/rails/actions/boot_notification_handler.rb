module Ocpp
  module Rails
    module Actions
      class BootNotificationHandler
        def initialize(charge_point, message_id, payload)
          @charge_point = charge_point
          @message_id = message_id
          @payload = payload
        end

        def call
          # Update charge point with boot information
          old_connected = @charge_point.connected
          
          @charge_point.update(
            vendor: @payload['chargePointVendor'],
            model: @payload['chargePointModel'],
            serial_number: @payload['chargePointSerialNumber'],
            firmware_version: @payload['firmwareVersion'],
            iccid: @payload['iccid'],
            imsi: @payload['imsi'],
            meter_type: @payload['meterType'],
            meter_serial_number: @payload['meterSerialNumber'],
            connected: true,
            last_heartbeat_at: Time.current
          )

          ::Rails.logger.info("[OCPP] BootNotification from #{@charge_point.identifier}: #{@payload['chargePointVendor']} #{@payload['chargePointModel']}")

          # Log connection state change if it actually changed
          log_connection_change(old_connected, true)

          # Return acceptance with heartbeat interval
          {
            'status' => 'Accepted',
            'currentTime' => Time.current.iso8601,
            'interval' => Ocpp::Rails.configuration.heartbeat_interval
          }
        end

        private

        def log_connection_change(old_connected, new_connected)
          return if old_connected == new_connected
          
          begin
            Ocpp::Rails::StateChange.create!(
              charge_point: @charge_point,
              change_type: "connection",
              connector_id: nil,
              old_value: old_connected.to_s,
              new_value: new_connected.to_s,
              metadata: { source: "boot_notification" }
            )
          rescue => error
            ::Rails.logger.error("Failed to log state change: #{error.message}")
          end
        end
      end
    end
  end
end
