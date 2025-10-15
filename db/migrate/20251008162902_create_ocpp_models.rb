class CreateOcppModels < ActiveRecord::Migration[8.0]
  def change

    # Charge Points
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
      t.json :metadata, default: {}
      t.timestamps
    end

    # Charge Sessions
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
      t.json :metadata, default: {}
      t.timestamps
    end

    add_index :ocpp_charging_sessions, [:charge_point_id, :connector_id]

    # Meter Values
    create_table :ocpp_meter_values do |t|
      t.references :charging_session, null: true, foreign_key: { to_table: :ocpp_charging_sessions }
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

    # Messages
    create_table :ocpp_messages do |t|
      t.references :charge_point, null: false, foreign_key: { to_table: :ocpp_charge_points }
      t.string :message_id, null: false
      t.string :direction, null: false # inbound, outbound
      t.string :action
      t.string :message_type # CALL, CALLRESULT, CALLERROR
      t.json :payload, default: {}
      t.string :status # pending, sent, received, error
      t.text :error_message
      t.timestamps
    end

    add_index :ocpp_messages, :message_id
    add_index :ocpp_messages, [:charge_point_id, :created_at]
  end
end
