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

          # Execute authorization hooks to determine access decision
          result = Ocpp::Rails::AuthorizationHookManager.execute_hooks(@charge_point.id, id_tag)

          # Persist authorization record for audit trail
          begin
            Ocpp::Rails::Authorization.create!(
              charge_point_id: @charge_point.id,
              id_tag: id_tag,
              status: result[:status],
              expiry_date: result[:expiry_date]
            )
          rescue => error
            ::Rails.logger.error("[OCPP] Failed to persist Authorization record: #{error.message}")
            # Continue - authorization decision already made, persistence failure shouldn't block response
          end

          # Build OCPP response
          id_tag_info = { 'status' => result[:status] }
          
          # Only include expiryDate if status is Accepted and expiry_date is present
          if result[:status] == 'Accepted' && result[:expiry_date].present?
            id_tag_info['expiryDate'] = result[:expiry_date].iso8601
          end

          {
            'idTagInfo' => id_tag_info
          }
        end
      end
    end
  end
end
