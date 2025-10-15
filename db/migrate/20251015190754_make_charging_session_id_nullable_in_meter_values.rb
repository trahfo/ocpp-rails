class MakeChargingSessionIdNullableInMeterValues < ActiveRecord::Migration[8.0]
  def change
    change_column_null :ocpp_meter_values, :charging_session_id, true
  end
end
