namespace :ocpp do
  namespace :state_changes do
    desc "Clean up old OCPP state change records"
    task cleanup: :environment do
      retention_days = ENV['RETENTION_DAYS']&.to_i || Ocpp::Rails.configuration.state_change_retention_days
      deleted_count = Ocpp::Rails::StateChange.older_than(retention_days).delete_all

      puts "Deleted #{deleted_count} StateChange records older than #{retention_days} days"
    end

    desc "Start the automatic cleanup job (runs daily)"
    task start_cleanup_job: :environment do
      Ocpp::Rails::CleanupStateChangesJob.perform_later

      puts "Automatic cleanup job started. It will run daily if cleanup is enabled."
    end
  end
end
