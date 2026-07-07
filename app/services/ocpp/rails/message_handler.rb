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
        when "CALL"
          handle_call(parsed)
        when "CALLRESULT"
          handle_callresult(parsed)
        when "CALLERROR"
          handle_callerror(parsed)
        when "PARSE_ERROR"
          log_error("Failed to parse message: #{parsed[:error]}")
          send_callerror(SecureRandom.uuid, "FormationViolation", "Invalid JSON format")
        when "UNKNOWN"
          log_error("Unknown message type: #{parsed[:raw]}")
          send_callerror(SecureRandom.uuid, "ProtocolError", "Unknown message type")
        end
      rescue => e
        send_internal_error(parsed && parsed[:message_id], e, "Error processing message")
      end

      private

      # Never place exception details in the CALLERROR sent to the station;
      # log them server-side under a reference the station response carries.
      def send_internal_error(message_id, exception, context)
        error_ref = SecureRandom.hex(8)
        log_error("#{context} (ref #{error_ref}): #{exception.class}: #{exception.message}")
        log_error(exception.backtrace.join("\n")) if exception.backtrace
        send_callerror(
          message_id || SecureRandom.uuid,
          "InternalError",
          "An internal error occurred",
          { "errorRef" => error_ref }
        )
      end

      def handle_call(parsed)
        # Log incoming message
        log_message(parsed, "inbound", "CALL")

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
        send_internal_error(parsed[:message_id], e, "Error in #{parsed[:action]} handler")
      end

      def handle_callresult(parsed)
        # Update pending outbound message with successful response
        message = Message.find_by(
          charge_point: charge_point,
          message_id: parsed[:message_id],
          direction: "outbound",
          status: "pending"
        )

        if message
          message.update(
            status: "received",
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
          direction: "outbound",
          status: "pending"
        )

        if message
          message.update(
            status: "error",
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
        log_message({ message_id: message_id, payload: payload }, "outbound", "CALLRESULT")
      end

      def send_callerror(message_id, error_code, error_description, details = {})
        response = Protocol.build_callerror(message_id, error_code, error_description, details)
        ChargePointChannel.broadcast_to(charge_point, { message: response })
        log_message(
          { message_id: message_id, error_code: error_code, error_description: error_description },
          "outbound",
          "CALLERROR"
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
          status: direction == "inbound" ? "received" : "sent"
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
