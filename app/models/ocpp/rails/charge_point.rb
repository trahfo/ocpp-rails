module Ocpp
  module Rails
    class ChargePoint < ApplicationRecord
      self.table_name = "ocpp_charge_points"

      has_many :charging_sessions, dependent: :destroy, class_name: "Ocpp::Rails::ChargingSession"
      has_many :meter_values, dependent: :destroy, class_name: "Ocpp::Rails::MeterValue"
      has_many :messages, dependent: :destroy, class_name: "Ocpp::Rails::Message"
      has_many :state_changes, dependent: :destroy, class_name: "Ocpp::Rails::StateChange"
      has_many :authorizations, dependent: :destroy, class_name: "Ocpp::Rails::Authorization"

      validates :identifier, presence: true, uniqueness: true
      validates :ocpp_protocol, inclusion: { in: Ocpp::Rails.supported_versions }

      scope :connected, -> { where(connected: true) }
      scope :available, -> { where(status: "Available") }
      scope :charging, -> { where(status: "Charging") }

      # Stores the station's Basic Auth password as a SHA-256 digest.
      # OCPP-J passwords are high-entropy machine credentials (the spec
      # mandates 16-40 random bytes), so a fast unsalted hash is appropriate,
      # like for API tokens.
      def auth_password=(password)
        self.auth_password_digest = password.nil? ? nil : Digest::SHA256.hexdigest(password)
      end

      def authenticate_password?(password)
        return false if auth_password_digest.blank? || password.blank?

        ActiveSupport::SecurityUtils.fixed_length_secure_compare(
          Digest::SHA256.hexdigest(password),
          auth_password_digest
        )
      end

      def heartbeat!
        old_connected = connected
        update(last_heartbeat_at: Time.current, connected: true)
        
        # Log connection state change only if reconnecting (false -> true)
        if old_connected == false
          begin
            state_changes.create!(
              change_type: "connection",
              connector_id: nil,
              old_value: "false",
              new_value: "true",
              metadata: { source: "heartbeat" }
            )
          rescue => error
            ::Rails.logger.error("Failed to log state change: #{error.message}")
          end
        end
      end

      def disconnect!
        update(connected: false)
      end

      def current_session
        charging_sessions.where(stopped_at: nil).order(started_at: :desc).first
      end

      def available?
        status == "Available" && connected?
      end
    end
  end
end
