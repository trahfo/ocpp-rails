class CreateOcppAuthorizations < ActiveRecord::Migration[8.0]
  def change
    create_table :ocpp_authorizations do |t|
      t.references :charge_point, null: false, foreign_key: { to_table: :ocpp_charge_points, on_delete: :cascade }
      t.string :id_tag, null: false
      t.string :status, null: false
      t.datetime :expiry_date

      t.timestamps
    end

    add_index :ocpp_authorizations, :charge_point_id
    add_index :ocpp_authorizations, :id_tag
    add_index :ocpp_authorizations, :created_at
  end
end
