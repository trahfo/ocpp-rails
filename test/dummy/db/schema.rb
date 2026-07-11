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

ActiveRecord::Schema[8.1].define(version: 2026_07_11_000001) do
  create_table "ocpp_authorizations", force: :cascade do |t|
    t.integer "charge_point_id", null: false
    t.datetime "created_at", null: false
    t.datetime "expiry_date"
    t.string "id_tag", null: false
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.index [ "charge_point_id" ], name: "index_ocpp_authorizations_on_charge_point_id"
    t.index [ "created_at" ], name: "index_ocpp_authorizations_on_created_at"
    t.index [ "id_tag" ], name: "index_ocpp_authorizations_on_id_tag"
  end

  create_table "ocpp_charge_points", force: :cascade do |t|
    t.string "auth_password_digest"
    t.boolean "connected", default: false
    t.datetime "created_at", null: false
    t.string "firmware_version"
    t.string "iccid"
    t.string "identifier", null: false
    t.string "imsi"
    t.datetime "last_heartbeat_at"
    t.json "metadata", default: {}
    t.string "meter_serial_number"
    t.string "meter_type"
    t.string "model"
    t.string "ocpp_protocol", default: "1.6"
    t.string "serial_number"
    t.string "status", default: "Available"
    t.datetime "updated_at", null: false
    t.string "vendor"
    t.index [ "identifier" ], name: "index_ocpp_charge_points_on_identifier", unique: true
  end

  create_table "ocpp_charging_sessions", force: :cascade do |t|
    t.integer "charge_point_id", null: false
    t.integer "connector_id", null: false
    t.datetime "created_at", null: false
    t.integer "duration_seconds"
    t.decimal "energy_consumed", precision: 10, scale: 2
    t.string "id_tag"
    t.json "metadata", default: {}
    t.decimal "start_meter_value", precision: 10, scale: 2
    t.datetime "started_at"
    t.string "status", default: "Preparing"
    t.decimal "stop_meter_value", precision: 10, scale: 2
    t.string "stop_reason"
    t.datetime "stopped_at"
    t.bigint "transaction_id"
    t.datetime "updated_at", null: false
    t.index [ "charge_point_id", "connector_id" ], name: "idx_on_charge_point_id_connector_id_097b46847b"
    t.index [ "charge_point_id", "connector_id" ], name: "index_ocpp_one_active_session_per_connector", unique: true, where: "stopped_at IS NULL"
    t.index [ "charge_point_id" ], name: "index_ocpp_charging_sessions_on_charge_point_id"
    t.index [ "transaction_id" ], name: "index_ocpp_charging_sessions_on_transaction_id", unique: true
  end

  create_table "ocpp_connector_statuses", force: :cascade do |t|
    t.integer "charge_point_id", null: false
    t.integer "connector_id", null: false
    t.datetime "created_at", null: false
    t.string "error_code"
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.index [ "charge_point_id", "connector_id" ], name: "idx_on_charge_point_id_connector_id_418819ba62", unique: true
    t.index [ "charge_point_id" ], name: "index_ocpp_connector_statuses_on_charge_point_id"
  end

  create_table "ocpp_messages", force: :cascade do |t|
    t.string "action"
    t.integer "charge_point_id", null: false
    t.datetime "created_at", null: false
    t.string "direction", null: false
    t.text "error_message"
    t.string "message_id", null: false
    t.string "message_type"
    t.json "payload", default: {}
    t.string "status"
    t.datetime "updated_at", null: false
    t.index [ "charge_point_id", "created_at" ], name: "index_ocpp_messages_on_charge_point_id_and_created_at"
    t.index [ "charge_point_id" ], name: "index_ocpp_messages_on_charge_point_id"
    t.index [ "message_id" ], name: "index_ocpp_messages_on_message_id"
  end

  create_table "ocpp_meter_values", force: :cascade do |t|
    t.integer "charge_point_id", null: false
    t.integer "charging_session_id"
    t.integer "connector_id"
    t.string "context"
    t.datetime "created_at", null: false
    t.string "flag_reason"
    t.boolean "flagged", default: false, null: false
    t.string "format"
    t.string "location"
    t.string "measurand"
    t.string "phase"
    t.string "raw_timestamp"
    t.datetime "timestamp"
    t.string "timestamp_source", default: "station", null: false
    t.string "unit"
    t.datetime "updated_at", null: false
    t.decimal "value", precision: 15, scale: 4
    t.index [ "charge_point_id" ], name: "index_ocpp_meter_values_on_charge_point_id"
    t.index [ "charging_session_id" ], name: "index_ocpp_meter_values_on_charging_session_id"
    t.index [ "measurand" ], name: "index_ocpp_meter_values_on_measurand"
    t.index [ "timestamp" ], name: "index_ocpp_meter_values_on_timestamp"
  end

  create_table "ocpp_state_changes", force: :cascade do |t|
    t.string "change_type", null: false
    t.integer "charge_point_id", null: false
    t.integer "connector_id"
    t.datetime "created_at", null: false
    t.json "metadata", default: {}
    t.string "new_value", null: false
    t.string "old_value"
    t.datetime "updated_at", null: false
    t.index [ "change_type", "created_at" ], name: "index_ocpp_state_changes_on_change_type_and_created_at"
    t.index [ "charge_point_id", "created_at" ], name: "index_ocpp_state_changes_on_charge_point_id_and_created_at"
    t.index [ "charge_point_id" ], name: "index_ocpp_state_changes_on_charge_point_id"
    t.index [ "created_at" ], name: "index_ocpp_state_changes_on_created_at"
  end

  add_foreign_key "ocpp_authorizations", "ocpp_charge_points", column: "charge_point_id", on_delete: :cascade
  add_foreign_key "ocpp_charging_sessions", "ocpp_charge_points", column: "charge_point_id"
  add_foreign_key "ocpp_connector_statuses", "ocpp_charge_points", column: "charge_point_id"
  add_foreign_key "ocpp_messages", "ocpp_charge_points", column: "charge_point_id"
  add_foreign_key "ocpp_meter_values", "ocpp_charge_points", column: "charge_point_id"
  add_foreign_key "ocpp_meter_values", "ocpp_charging_sessions", column: "charging_session_id"
  add_foreign_key "ocpp_state_changes", "ocpp_charge_points", column: "charge_point_id", on_delete: :cascade
end
