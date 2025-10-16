class CreateOcppStateChanges < ActiveRecord::Migration[8.0]
  def change
    create_table :ocpp_state_changes do |t|
      t.references :charge_point, null: false, foreign_key: { to_table: :ocpp_charge_points, on_delete: :cascade }
      t.string :change_type, null: false
      t.integer :connector_id
      t.string :old_value
      t.string :new_value, null: false
      t.json :metadata, default: {}
      t.timestamps
    end

    add_index :ocpp_state_changes, [:charge_point_id, :created_at]
    add_index :ocpp_state_changes, [:change_type, :created_at]
    add_index :ocpp_state_changes, :created_at
  end
end
