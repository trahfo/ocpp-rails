namespace :ocpp do
  namespace :authorizations do
    desc "Clean up old OCPP authorization records"
    task cleanup: :environment do
      retention_days = ENV['RETENTION_DAYS']&.to_i || Ocpp::Rails.configuration.authorization_retention_days
      deleted_count = Ocpp::Rails::Authorization.older_than(retention_days).delete_all

      puts "Deleted #{deleted_count} Authorization records older than #{retention_days} days"
    end

    desc "Start the automatic cleanup job (runs daily)"
    task start_cleanup_job: :environment do
      Ocpp::Rails::CleanupAuthorizationsJob.perform_later

      puts "Automatic cleanup job started. It will run daily if cleanup is enabled."
    end
  end
end
