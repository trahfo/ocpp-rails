module Ocpp
  module Rails
    class CleanupStateChangesJob < ApplicationJob
      queue_as :ocpp_maintenance

      def perform
        unless Ocpp::Rails.configuration.state_change_cleanup_enabled
          ::Rails.logger.info("StateChange cleanup disabled, skipping")
          return
        end

        begin
          retention_days = Ocpp::Rails.configuration.state_change_retention_days
          deleted_count = Ocpp::Rails::StateChange.older_than(retention_days).delete_all

          ::Rails.logger.info("Deleted #{deleted_count} StateChange records older than #{retention_days} days")
        rescue => error
          ::Rails.logger.error("StateChange cleanup failed: #{error.message}")
        ensure
          # Re-enqueue for next run (24 hours later) only if cleanup is enabled
          if Ocpp::Rails.configuration.state_change_cleanup_enabled
            self.class.set(wait: 24.hours).perform_later
          end
        end
      end
    end
  end
end
