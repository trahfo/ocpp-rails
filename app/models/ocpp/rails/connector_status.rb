module Ocpp
  module Rails
    class ConnectorStatus < ApplicationRecord
      self.table_name = "ocpp_connector_statuses"

      belongs_to :charge_point, class_name: "Ocpp::Rails::ChargePoint"

      # Connector 0 (the charge point main controller) is tracked on
      # ChargePoint#status, never here.
      validates :connector_id, presence: true,
        numericality: { greater_than_or_equal_to: 1, only_integer: true },
        uniqueness: { scope: :charge_point_id }
      validates :status, presence: true
    end
  end
end
