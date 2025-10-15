module Ocpp
  module Rails
    class ChargingSession < ApplicationRecord
      self.table_name = "ocpp_charging_sessions"

      belongs_to :charge_point, class_name: "Ocpp::Rails::ChargePoint"
      has_many :meter_values, dependent: :destroy, class_name: "Ocpp::Rails::MeterValue"

      validates :connector_id, presence: true
      validates :transaction_id, uniqueness: true, allow_nil: true

      scope :active, -> { where(stopped_at: nil) }
      scope :completed, -> { where.not(stopped_at: nil) }

      before_create :generate_transaction_id

      def active?
        stopped_at.nil?
      end

      def stop!(reason: "Local", meter_value: nil)
        update(
          stopped_at: Time.current,
          stop_meter_value: meter_value,
          stop_reason: reason,
          duration_seconds: calculate_duration,
          energy_consumed: calculate_energy_consumed(meter_value),
          status: "Completed"
        )
      end

      def calculate_duration
        return 0 unless started_at
        ((stopped_at || Time.current) - started_at).to_i
      end

      def calculate_energy_consumed(stop_value = nil)
        return 0 unless start_meter_value
        stop_val = stop_value || stop_meter_value || start_meter_value
        stop_val - start_meter_value
      end

      private

      def generate_transaction_id
        self.transaction_id ||= SecureRandom.uuid
      end
    end
  end
end
