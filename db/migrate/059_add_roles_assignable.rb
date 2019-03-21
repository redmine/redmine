class AddRolesAssignable < ActiveRecord::Migration[4.2]
  def self.up
    add_column :roles, :assignable, :boolean, :default => true
  end

  def self.down
    remove_column :roles, :assignable
  end
end
