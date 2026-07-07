class ConvertOcppTransactionIdToInteger < ActiveRecord::Migration[8.0]
  # The old string column held internally generated UUIDs that were never
  # sent on the wire (handlers used the AR primary key instead), so the
  # values are safe to drop. OCPP 1.6 requires an integer transactionId,
  # managed by the central system and decoupled from the primary key.
  def up
    remove_index :ocpp_charging_sessions, :transaction_id
    remove_column :ocpp_charging_sessions, :transaction_id
    add_column :ocpp_charging_sessions, :transaction_id, :bigint
    add_index :ocpp_charging_sessions, :transaction_id, unique: true
  end

  def down
    remove_index :ocpp_charging_sessions, :transaction_id
    remove_column :ocpp_charging_sessions, :transaction_id
    add_column :ocpp_charging_sessions, :transaction_id, :string
    add_index :ocpp_charging_sessions, :transaction_id, unique: true
  end
end
