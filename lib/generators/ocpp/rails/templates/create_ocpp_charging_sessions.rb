class CreateOcppChargingSessions < ActiveRecord::Migration[<%= ActiveRecord::Migration.current_version %>]
  def change
    create_table :ocpp_charging_sessions do |t|
      t.references :charge_point, null: false, foreign_key: { to_table: :ocpp_charge_points }
      t.integer :connector_id, null: false
      t.string :transaction_id, index: { unique: true }
      t.string :id_tag
      t.string :status, default: "Preparing"
      t.datetime :started_at
      t.datetime :stopped_at
      t.decimal :start_meter_value, precision: 10, scale: 2
      t.decimal :stop_meter_value, precision: 10, scale: 2
      t.decimal :energy_consumed, precision: 10, scale: 2
      t.integer :duration_seconds
      t.string :stop_reason
      t.jsonb :metadata, default: {}
      t.timestamps
    end

    add_index :ocpp_charging_sessions, [:charge_point_id, :connector_id]
  end
end
