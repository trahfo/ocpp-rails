class CreateOcppChargePoints < ActiveRecord::Migration[<%= ActiveRecord::Migration.current_version %>]
  def change
    create_table :ocpp_charge_points do |t|
      t.string :identifier, null: false, index: { unique: true }
      t.string :vendor
      t.string :model
      t.string :serial_number
      t.string :firmware_version
      t.string :iccid
      t.string :imsi
      t.string :meter_type
      t.string :meter_serial_number
      t.string :ocpp_protocol, default: "1.6"
      t.string :status, default: "Available"
      t.datetime :last_heartbeat_at
      t.boolean :connected, default: false
      t.jsonb :metadata, default: {}
      t.timestamps
    end
  end
end
