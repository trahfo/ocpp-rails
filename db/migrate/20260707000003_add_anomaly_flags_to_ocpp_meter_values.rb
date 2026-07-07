class AddAnomalyFlagsToOcppMeterValues < ActiveRecord::Migration[8.0]
  def change
    add_column :ocpp_meter_values, :flagged, :boolean, default: false, null: false
    add_column :ocpp_meter_values, :flag_reason, :string
  end
end
