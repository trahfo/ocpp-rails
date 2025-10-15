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

          # Return acceptance with heartbeat interval
          {
            'status' => 'Accepted',
            'currentTime' => Time.current.iso8601,
            'interval' => Ocpp::Rails.configuration.heartbeat_interval
          }
        end
      end
    end
  end
end
