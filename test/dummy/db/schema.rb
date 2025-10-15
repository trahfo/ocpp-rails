# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_10_15_190754) do
  create_table "ocpp_charge_points", force: :cascade do |t|
    t.string "identifier", null: false
    t.string "vendor"
    t.string "model"
    t.string "serial_number"
    t.string "firmware_version"
    t.string "iccid"
    t.string "imsi"
    t.string "meter_type"
    t.string "meter_serial_number"
    t.string "ocpp_protocol", default: "1.6"
    t.string "status", default: "Available"
    t.datetime "last_heartbeat_at"
    t.boolean "connected", default: false
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["identifier"], name: "index_ocpp_charge_points_on_identifier", unique: true
  end

  create_table "ocpp_charging_sessions", force: :cascade do |t|
    t.integer "charge_point_id", null: false
    t.integer "connector_id", null: false
    t.string "transaction_id"
    t.string "id_tag"
    t.string "status", default: "Preparing"
    t.datetime "started_at"
    t.datetime "stopped_at"
    t.decimal "start_meter_value", precision: 10, scale: 2
    t.decimal "stop_meter_value", precision: 10, scale: 2
    t.decimal "energy_consumed", precision: 10, scale: 2
    t.integer "duration_seconds"
    t.string "stop_reason"
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["charge_point_id", "connector_id"], name: "idx_on_charge_point_id_connector_id_097b46847b"
    t.index ["charge_point_id"], name: "index_ocpp_charging_sessions_on_charge_point_id"
    t.index ["transaction_id"], name: "index_ocpp_charging_sessions_on_transaction_id", unique: true
  end

  create_table "ocpp_messages", force: :cascade do |t|
    t.integer "charge_point_id", null: false
    t.string "message_id", null: false
    t.string "direction", null: false
    t.string "action"
    t.string "message_type"
    t.json "payload", default: {}
    t.string "status"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["charge_point_id", "created_at"], name: "index_ocpp_messages_on_charge_point_id_and_created_at"
    t.index ["charge_point_id"], name: "index_ocpp_messages_on_charge_point_id"
    t.index ["message_id"], name: "index_ocpp_messages_on_message_id"
  end

  create_table "ocpp_meter_values", force: :cascade do |t|
    t.integer "charging_session_id"
    t.integer "charge_point_id", null: false
    t.integer "connector_id"
    t.string "measurand"
    t.string "phase"
    t.string "unit"
    t.string "context"
    t.string "format"
    t.string "location"
    t.decimal "value", precision: 15, scale: 4
    t.datetime "timestamp"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["charge_point_id"], name: "index_ocpp_meter_values_on_charge_point_id"
    t.index ["charging_session_id"], name: "index_ocpp_meter_values_on_charging_session_id"
    t.index ["measurand"], name: "index_ocpp_meter_values_on_measurand"
    t.index ["timestamp"], name: "index_ocpp_meter_values_on_timestamp"
  end

  add_foreign_key "ocpp_charging_sessions", "ocpp_charge_points", column: "charge_point_id"
  add_foreign_key "ocpp_messages", "ocpp_charge_points", column: "charge_point_id"
  add_foreign_key "ocpp_meter_values", "ocpp_charge_points", column: "charge_point_id"
  add_foreign_key "ocpp_meter_values", "ocpp_charging_sessions", column: "charging_session_id"
end
