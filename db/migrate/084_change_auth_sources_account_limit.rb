class ChangeAuthSourcesAccountLimit < ActiveRecord::Migration[4.2]
  def self.up
    change_column :auth_sources, :account, :string, :limit => nil
  end

  def self.down
    change_column :auth_sources, :account, :string, :limit => 60
  end
end
