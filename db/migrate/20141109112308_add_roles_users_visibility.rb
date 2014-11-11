class AddRolesUsersVisibility < ActiveRecord::Migration
  def self.up
    add_column :roles, :users_visibility, :string, :limit => 30, :default => 'all', :null => false
  end

  def self.down
    remove_column :roles, :users_visibility
  end
end
