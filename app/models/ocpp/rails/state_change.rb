module Ocpp
  module Rails
    class StateChange < ApplicationRecord
      self.table_name = "ocpp_state_changes"

      belongs_to :charge_point, class_name: "Ocpp::Rails::ChargePoint"

      validates :change_type, presence: true, inclusion: { in: ["status", "connection"] }
      validates :new_value, presence: true
      validates :connector_id, numericality: { greater_than_or_equal_to: 0, only_integer: true }, allow_nil: true

      scope :status_changes, -> { where(change_type: "status") }
      scope :connection_changes, -> { where(change_type: "connection") }
      scope :for_connector, ->(connector_id) { where(connector_id: connector_id) }
      scope :older_than, ->(days) { where("created_at < ?", days.days.ago) }

      after_commit :trigger_hooks, on: :create

      private

      def trigger_hooks
        Ocpp::Rails::StateChangeHookManager.execute_hooks(self)
      end
    end
  end
end
