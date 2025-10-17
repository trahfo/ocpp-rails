module Ocpp
  module Rails
    class CleanupAuthorizationsJob < ApplicationJob
      queue_as :ocpp_maintenance

      def perform
        unless Ocpp::Rails.configuration.authorization_cleanup_enabled
          ::Rails.logger.info("Authorization cleanup disabled, skipping")
          return
        end

        begin
          retention_days = Ocpp::Rails.configuration.authorization_retention_days
          deleted_count = Ocpp::Rails::Authorization.older_than(retention_days).delete_all

          ::Rails.logger.info("Deleted #{deleted_count} Authorization records older than #{retention_days} days")
        rescue => error
          ::Rails.logger.error("Authorization cleanup failed: #{error.message}")
        ensure
          # Re-enqueue for next run (24 hours later) only if cleanup is enabled
          if Ocpp::Rails.configuration.authorization_cleanup_enabled
            self.class.set(wait: 24.hours).perform_later
          end
        end
      end
    end
  end
end
