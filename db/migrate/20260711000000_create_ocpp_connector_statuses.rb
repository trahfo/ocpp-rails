class CreateOcppConnectorStatuses < ActiveRecord::Migration[8.0]
  def change
    create_table :ocpp_connector_statuses do |t|
      t.references :charge_point, null: false, foreign_key: { to_table: :ocpp_charge_points }
      t.integer :connector_id, null: false
      t.string :status, null: false
      t.string :error_code
      t.timestamps
    end

    add_index :ocpp_connector_statuses, [ :charge_point_id, :connector_id ], unique: true
  end
end
