class RemoveIdentityUrlFromUsers < ActiveRecord::Migration[6.1]
  def change
    remove_column :users, :identity_url, :string
  end
end
