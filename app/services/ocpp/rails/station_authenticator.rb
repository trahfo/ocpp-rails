module Ocpp
  module Rails
    # OCPP-J Security Profile 1: HTTP Basic Auth on the WebSocket upgrade.
    # The username must equal the charge point identity and the password must
    # match the per-station credential stored (hashed) on the ChargePoint.
    # Profile 2 additionally requires TLS, terminated in front of the app.
    module StationAuthenticator
      Result = Struct.new(:charge_point, :failure) do
        def success?
          failure.nil?
        end
      end

      def self.authenticate(identifier:, authorization_header:)
        charge_point = ChargePoint.find_by(identifier: identifier)
        return failure(:unknown_charge_point) unless charge_point

        return Result.new(charge_point, nil) if Ocpp::Rails.configuration.authentication_mode == :none

        username, password = decode_basic(authorization_header)
        return failure(:missing_credentials) if username.nil?

        # OCPP-J requires the Basic Auth username to equal the station identity
        return failure(:identity_mismatch) unless username == identifier
        return failure(:no_credential_configured) if charge_point.auth_password_digest.blank?
        return failure(:invalid_credentials) unless charge_point.authenticate_password?(password)

        Result.new(charge_point, nil)
      end

      def self.decode_basic(header)
        return nil unless header.is_a?(String) && header.start_with?("Basic ")

        decoded = Base64.strict_decode64(header.delete_prefix("Basic "))
        decoded.split(":", 2)
      rescue ArgumentError
        nil
      end

      def self.failure(reason)
        Result.new(nil, reason)
      end
      private_class_method :failure
    end
  end
end
