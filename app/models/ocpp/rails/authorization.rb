module Ocpp
  module Rails
    class Authorization < ApplicationRecord
      self.table_name = "ocpp_authorizations"

      belongs_to :charge_point, class_name: "Ocpp::Rails::ChargePoint"

      validates :status, presence: true, inclusion: { in: ["Accepted", "Blocked", "Expired", "Invalid", "ConcurrentTx"] }
      validates :id_tag, presence: true
      validates :charge_point, presence: true

      scope :accepted, -> { where(status: "Accepted") }
      scope :rejected, -> { where.not(status: "Accepted") }
      scope :for_id_tag, ->(tag) { where(id_tag: tag) }
      scope :older_than, ->(days) { where("created_at < ?", days.days.ago) }

      after_commit :trigger_async_hooks, on: :create

      private

      def trigger_async_hooks
        Ocpp::Rails::AuthorizationHookManager.execute_async_hooks(self)
      end
    end
  end
end
