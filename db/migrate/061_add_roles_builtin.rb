class AddRolesBuiltin < ActiveRecord::Migration[4.2]
  def self.up
    add_column :roles, :builtin, :integer, :default => 0, :null => false
  end

  def self.down
    remove_column :roles, :builtin
  end
end
