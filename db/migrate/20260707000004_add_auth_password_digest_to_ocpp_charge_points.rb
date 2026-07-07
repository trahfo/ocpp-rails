class AddAuthPasswordDigestToOcppChargePoints < ActiveRecord::Migration[8.0]
  def change
    add_column :ocpp_charge_points, :auth_password_digest, :string
  end
end
