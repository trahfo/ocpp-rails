module Ocpp
  module Rails
    module Actions
      class AuthorizeHandler
        def initialize(charge_point, message_id, payload)
          @charge_point = charge_point
          @message_id = message_id
          @payload = payload
        end

        def call
          id_tag = @payload['idTag']

          ::Rails.logger.info("[OCPP] Authorize request from #{@charge_point.identifier} for idTag: #{id_tag}")

          # Default implementation: Accept all tags
          # Host application should override this handler to implement custom authorization logic
          # such as checking against a database of valid RFID tags, checking user accounts, etc.

          {
            'idTagInfo' => {
              'status' => 'Accepted',
              'expiryDate' => (Time.current + 1.year).iso8601
            }
          }
        end
      end
    end
  end
end
