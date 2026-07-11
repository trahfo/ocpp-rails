class BackfillOcppConnectorStatuses < ActiveRecord::Migration[8.0]
  def up
    Ocpp::Rails::ConnectorStatusBackfill.run
  end

  def down
    # Data-only migration; the legacy metadata keys are not restored.
  end
end
