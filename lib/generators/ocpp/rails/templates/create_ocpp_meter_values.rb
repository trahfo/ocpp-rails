class CreateOcppMeterValues < ActiveRecord::Migration[<%= ActiveRecord::Migration.current_version %>]
  def change
    create_table :ocpp_meter_values do |t|
      t.references :charging_session, null: false, foreign_key: { to_table: :ocpp_charging_sessions }
      t.references :charge_point, null: false, foreign_key: { to_table: :ocpp_charge_points }
      t.integer :connector_id
      t.string :measurand
      t.string :phase
      t.string :unit
      t.string :context
      t.string :format
      t.string :location
      t.decimal :value, precision: 15, scale: 4
      t.datetime :timestamp
      t.timestamps
    end

    add_index :ocpp_meter_values, :measurand
    add_index :ocpp_meter_values, :timestamp
  end
end
