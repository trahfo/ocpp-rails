class CreateOcppMessages < ActiveRecord::Migration[<%= ActiveRecord::Migration.current_version %>]
  def change
    create_table :ocpp_messages do |t|
      t.references :charge_point, null: false, foreign_key: { to_table: :ocpp_charge_points }
      t.string :message_id, null: false
      t.string :direction, null: false # inbound, outbound
      t.string :action
      t.string :message_type # CALL, CALLRESULT, CALLERROR
      t.jsonb :payload, default: {}
      t.string :status # pending, sent, received, error
      t.text :error_message
      t.timestamps
    end

    add_index :ocpp_messages, :message_id
    add_index :ocpp_messages, [:charge_point_id, :created_at]
  end
end
