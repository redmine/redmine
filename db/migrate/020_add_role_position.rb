class AddRolePosition < ActiveRecord::Migration
  def self.up
    add_column :roles, :position, :integer, :default => 1
    Role.update_all("position = (SELECT COUNT(*) FROM #{Role.table_name} r WHERE r.id < id) + 1")
  end

  def self.down
    remove_column :roles, :position
  end
end
