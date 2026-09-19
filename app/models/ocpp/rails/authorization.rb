module Ocpp
  module Rails
    class Authorization < ApplicationRecord
      self.table_name = "ocpp_authorizations"

      belongs_to :charge_point, class_name: "Ocpp::Rails::ChargePoint"

      validates :status, presence: true, inclusion: { in: [ "Accepted", "Blocked", "Expired", "Invalid", "ConcurrentTx" ] }
      validates :charge_point, presence: true

      # A station charging under PlugAndCharge presents no token at all: the
      # idTag arrives empty (or absent) on Authorize and StartTransaction,
      # while an authorization hook still returns a real decision for it.
      # Requiring a token here only meant that decision was never recorded --
      # the handlers rescue the validation failure and log an error, so a
      # PlugAndCharge site produced a line of noise per message and no audit
      # row at all. A missing token is normalised to "" instead, which the
      # NOT NULL column takes and which reads back as "none presented".
      before_validation { self.id_tag = id_tag.to_s }

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
