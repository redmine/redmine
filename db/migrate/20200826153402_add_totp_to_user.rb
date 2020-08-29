class AddTotpToUser < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :twofa_totp_key, :string
    add_column :users, :twofa_totp_last_used_at, :integer
  end
end
