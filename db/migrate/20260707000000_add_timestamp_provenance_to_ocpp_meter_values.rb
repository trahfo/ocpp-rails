class AddTimestampProvenanceToOcppMeterValues < ActiveRecord::Migration[8.0]
  def change
    add_column :ocpp_meter_values, :raw_timestamp, :string
    add_column :ocpp_meter_values, :timestamp_source, :string, default: "station", null: false
  end
end
