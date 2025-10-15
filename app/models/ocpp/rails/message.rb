module Ocpp
  module Rails
    class Message < ApplicationRecord
      self.table_name = "ocpp_messages"

      belongs_to :charge_point, class_name: "Ocpp::Rails::ChargePoint"

      validates :message_id, presence: true
      validates :direction, inclusion: { in: %w[inbound outbound] }
      validates :message_type, inclusion: { in: %w[CALL CALLRESULT CALLERROR] }

      scope :inbound, -> { where(direction: "inbound") }
      scope :outbound, -> { where(direction: "outbound") }
      scope :recent, -> { order(created_at: :desc) }
    end
  end
end
