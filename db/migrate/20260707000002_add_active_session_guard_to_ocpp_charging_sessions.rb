class AddActiveSessionGuardToOcppChargingSessions < ActiveRecord::Migration[8.0]
  # At most one non-stopped session per (charge point, connector), enforced
  # at the database so duplicate/racing StartTransaction messages cannot open
  # concurrent sessions. Partial indexes are supported by SQLite and Postgres.
  def change
    add_index :ocpp_charging_sessions, [ :charge_point_id, :connector_id ],
      unique: true,
      where: "stopped_at IS NULL",
      name: "index_ocpp_one_active_session_per_connector"
  end
end
