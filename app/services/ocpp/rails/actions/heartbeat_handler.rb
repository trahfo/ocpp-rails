module Ocpp
  module Rails
    module Actions
      class HeartbeatHandler
        def initialize(charge_point, message_id, payload)
          @charge_point = charge_point
          @message_id = message_id
          @payload = payload
        end

        def call
          # Update last heartbeat timestamp and ensure connected status
          @charge_point.heartbeat!

          ::Rails.logger.debug("[OCPP] Heartbeat from #{@charge_point.identifier}")

          # Return current server time
          {
            'currentTime' => Time.current.iso8601
          }
        end
      end
    end
  end
end
