module Ocpp
  module Rails
    class MessageHandler
      attr_reader :charge_point, :raw_message

      def initialize(charge_point, raw_message)
        @charge_point = charge_point
        @raw_message = raw_message
      end

      def process
        parsed = Protocol.parse(raw_message)

        case parsed[:type]
        when 'CALL'
          handle_call(parsed)
        when 'CALLRESULT'
          handle_callresult(parsed)
        when 'CALLERROR'
          handle_callerror(parsed)
        when 'PARSE_ERROR'
          log_error("Failed to parse message: #{parsed[:error]}")
          send_callerror(SecureRandom.uuid, "FormationViolation", "Invalid JSON format")
        when 'UNKNOWN'
          log_error("Unknown message type: #{parsed[:raw]}")
          send_callerror(SecureRandom.uuid, "ProtocolError", "Unknown message type")
        end
      rescue => e
        log_error("Error processing message: #{e.message}")
        log_error(e.backtrace.join("\n"))
        send_callerror(parsed[:message_id] || SecureRandom.uuid, "InternalError", e.message) if parsed
      end

      private

      def handle_call(parsed)
        # Log incoming message
        log_message(parsed, 'inbound', 'CALL')

        # Route to appropriate handler
        handler_class_name = "Ocpp::Rails::Actions::#{parsed[:action]}Handler"

        begin
          handler_class = handler_class_name.constantize
        rescue NameError
          send_callerror(parsed[:message_id], "NotSupported", "Action #{parsed[:action]} not supported")
          return
        end

        handler = handler_class.new(charge_point, parsed[:message_id], parsed[:payload])
        response = handler.call
        send_callresult(parsed[:message_id], response)
      rescue => e
        log_error("Error in #{parsed[:action]} handler: #{e.message}")
        send_callerror(parsed[:message_id], "InternalError", e.message)
      end

      def handle_callresult(parsed)
        # Update pending outbound message with successful response
        message = Message.find_by(
          charge_point: charge_point,
          message_id: parsed[:message_id],
          direction: 'outbound',
          status: 'pending'
        )

        if message
          message.update(
            status: 'received',
            payload: message.payload.merge(response: parsed[:payload])
          )
          log_info("Received CALLRESULT for #{message.action}")
        else
          log_warn("Received CALLRESULT for unknown message_id: #{parsed[:message_id]}")
        end
      end

      def handle_callerror(parsed)
        # Update pending outbound message with error response
        message = Message.find_by(
          charge_point: charge_point,
          message_id: parsed[:message_id],
          direction: 'outbound',
          status: 'pending'
        )

        if message
          message.update(
            status: 'error',
            error_message: "#{parsed[:error_code]}: #{parsed[:error_description]}",
            payload: message.payload.merge(error_details: parsed[:details])
          )
          log_error("Received CALLERROR for #{message.action}: #{parsed[:error_code]}")
        else
          log_warn("Received CALLERROR for unknown message_id: #{parsed[:message_id]}")
        end
      end

      def send_callresult(message_id, payload)
        response = Protocol.build_callresult(message_id, payload)
        ChargePointChannel.broadcast_to(charge_point, { message: response })
        log_message({ message_id: message_id, payload: payload }, 'outbound', 'CALLRESULT')
      end

      def send_callerror(message_id, error_code, error_description, details = {})
        response = Protocol.build_callerror(message_id, error_code, error_description, details)
        ChargePointChannel.broadcast_to(charge_point, { message: response })
        log_message(
          { message_id: message_id, error_code: error_code, error_description: error_description },
          'outbound',
          'CALLERROR'
        )
      end

      def log_message(parsed, direction, message_type)
        Message.create!(
          charge_point: charge_point,
          message_id: parsed[:message_id],
          direction: direction,
          action: parsed[:action],
          message_type: message_type,
          payload: parsed[:payload] || parsed[:error_code] || {},
          status: direction == 'inbound' ? 'received' : 'sent'
        )
      rescue => e
        log_error("Failed to log message: #{e.message}")
      end

      def log_error(message)
        ::Rails.logger.error("[OCPP] ChargePoint #{charge_point.identifier}: #{message}")
      end

      def log_warn(message)
        ::Rails.logger.warn("[OCPP] ChargePoint #{charge_point.identifier}: #{message}")
      end

      def log_info(message)
        ::Rails.logger.info("[OCPP] ChargePoint #{charge_point.identifier}: #{message}")
      end
    end
  end
end
