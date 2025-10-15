module Ocpp
  module Rails
    module Protocol
      class << self
        # Build a CALL message (request from server to charge point or charge point to server)
        # Format: [2, "message_id", "Action", {payload}]
        def build_call(message_id, action, payload)
          [2, message_id, action, payload].to_json
        end

        # Build a CALLRESULT message (successful response)
        # Format: [3, "message_id", {payload}]
        def build_callresult(message_id, payload)
          [3, message_id, payload].to_json
        end

        # Build a CALLERROR message (error response)
        # Format: [4, "message_id", "error_code", "error_description", {details}]
        def build_callerror(message_id, error_code, error_description, details = {})
          [4, message_id, error_code, error_description, details].to_json
        end

        # Parse incoming JSON-RPC 2.0 message
        def parse(raw_message)
          data = JSON.parse(raw_message)

          case data[0]
          when 2
            {
              type: 'CALL',
              message_id: data[1],
              action: data[2],
              payload: data[3] || {}
            }
          when 3
            {
              type: 'CALLRESULT',
              message_id: data[1],
              payload: data[2] || {}
            }
          when 4
            {
              type: 'CALLERROR',
              message_id: data[1],
              error_code: data[2],
              error_description: data[3],
              details: data[4] || {}
            }
          else
            {
              type: 'UNKNOWN',
              raw: data
            }
          end
        rescue JSON::ParserError => e
          {
            type: 'PARSE_ERROR',
            error: e.message,
            raw: raw_message
          }
        end
      end
    end
  end
end
