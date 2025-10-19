module Ocpp
  module Rails
    class Connection < ActionCable::Connection::Base
      attr_reader :username, :password, :charge_point_id

      def connect
        # Step 1: Extract credentials from HTTP Basic Auth header
        username, password = extract_credentials_from_header

        # Step 2: Extract charge_point_id from URL path
        charge_point_id = request.params[:charge_point_id]

        # Step 3: Execute sync hooks and get result
        auth_result = ConnectionAuthHookManager.execute_hooks(username, password, charge_point_id)

        # Step 4: Enqueue async hooks (before connection decision is enforced)
        ConnectionAuthHookManager.execute_async_hooks(username, password, charge_point_id)

        # Step 5: Make connection decision based on sync hook result
        if auth_result == false
          ::Rails.logger.warn("Connection authentication failed for charge_point_id: #{charge_point_id}")
          reject_unauthorized_connection
        end

        # Step 6: Store credentials in connection object (only reached if auth_result is true)
        @username = username
        @password = password
        @charge_point_id = charge_point_id
      end

      private

      def extract_credentials_from_header
        auth_header = request.env['HTTP_AUTHORIZATION']

        # Case 1: No Authorization header
        if auth_header.nil? || !auth_header.start_with?('Basic ')
          ::Rails.logger.warn("Malformed Authorization header received") if auth_header && !auth_header.start_with?('Basic ')
          return [nil, nil]
        end

        # Case 2: Decode credentials
        begin
          # Strip "Basic " prefix and decode Base64
          encoded_credentials = auth_header.sub(/^Basic /, '')
          decoded_credentials = Base64.strict_decode64(encoded_credentials)

          # Case 4: Split on first ':' only (handles passwords with colons)
          parts = decoded_credentials.split(':', 2)
          username = parts[0]
          password = parts[1] || ""  # Case 5: No colon found, password is empty string

          return [username, password]
        rescue ArgumentError => e
          # Case 3: Base64 decoding failure
          ::Rails.logger.error("Failed to decode Authorization header: #{e.message}")
          reject_unauthorized_connection
        end
      end
    end
  end
end
