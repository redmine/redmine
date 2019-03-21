class AddRolesUsersVisibility < ActiveRecord::Migration[4.2]
  def self.up
    add_column :roles, :users_visibility, :string, :limit => 30, :default => 'all', :null => false
  end

  def self.down
    remove_column :roles, :users_visibility
  end
end
