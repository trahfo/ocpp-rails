module Ocpp
  module Rails
    class ChargePoint < ApplicationRecord
      self.table_name = "ocpp_charge_points"

      has_many :charging_sessions, dependent: :destroy, class_name: "Ocpp::Rails::ChargingSession"
      has_many :connector_statuses, dependent: :destroy, class_name: "Ocpp::Rails::ConnectorStatus"
      has_many :meter_values, dependent: :destroy, class_name: "Ocpp::Rails::MeterValue"
      has_many :messages, dependent: :destroy, class_name: "Ocpp::Rails::Message"
      has_many :state_changes, dependent: :destroy, class_name: "Ocpp::Rails::StateChange"
      has_many :authorizations, dependent: :destroy, class_name: "Ocpp::Rails::Authorization"

      validates :identifier, presence: true, uniqueness: true
      validates :ocpp_protocol, inclusion: { in: Ocpp::Rails.supported_versions }

      scope :connected, -> { where(connected: true) }
      scope :available, -> { where(status: "Available") }
      # Charging is a fact about sessions, not about ChargePoint#status
      # (which only ever holds connector-0 values: Available/Unavailable/Faulted).
      scope :charging, -> { joins(:charging_sessions).merge(Ocpp::Rails::ChargingSession.active).distinct }

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

      # Last status the station reported for this connector via
      # StatusNotification; nil until the connector has reported once.
      def connector_status(connector_id)
        connector_statuses.find_by(connector_id: connector_id)&.status
      end

      def connector_error_code(connector_id)
        connector_statuses.find_by(connector_id: connector_id)&.error_code
      end

      # Whether a transaction is running on the connector. Authoritative by
      # definition, unlike connector_status which is only as fresh as the
      # station's last StatusNotification.
      def connector_charging?(connector_id)
        charging_sessions.active.where(connector_id: connector_id).exists?
      end
    end
  end
end
