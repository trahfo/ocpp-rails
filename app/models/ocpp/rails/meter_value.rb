module Ocpp
  module Rails
    class MeterValue < ApplicationRecord
      self.table_name = "ocpp_meter_values"

      belongs_to :charging_session, optional: true, class_name: "Ocpp::Rails::ChargingSession"
      belongs_to :charge_point, class_name: "Ocpp::Rails::ChargePoint"

      validates :measurand, presence: true

      scope :energy, -> { where(measurand: "Energy.Active.Import.Register") }
      scope :power, -> { where(measurand: "Power.Active.Import") }
      scope :current, -> { where(measurand: "Current.Import") }
      scope :voltage, -> { where(measurand: "Voltage") }
      scope :recent, -> { order(timestamp: :desc) }
    end
  end
end
