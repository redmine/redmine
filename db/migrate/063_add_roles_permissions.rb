class AddRolesPermissions < ActiveRecord::Migration[4.2]
  def self.up
    add_column :roles, :permissions, :text
  end

  def self.down
    remove_column :roles, :permissions
  end
end
