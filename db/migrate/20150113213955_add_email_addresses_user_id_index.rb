class AddEmailAddressesUserIdIndex < ActiveRecord::Migration[4.2]
  def up
    add_index :email_addresses, :user_id
  end

  def down
    remove_index :email_addresses, :user_id
  end
end
