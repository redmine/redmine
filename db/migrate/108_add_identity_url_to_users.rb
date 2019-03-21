class AddIdentityUrlToUsers < ActiveRecord::Migration[4.2]
  def self.up
    add_column :users, :identity_url, :string
  end

  def self.down
    remove_column :users, :identity_url
  end
end
