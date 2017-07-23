class AddRolePosition < ActiveRecord::Migration[4.2]
  def self.up
    add_column :roles, :position, :integer, :default => 1
    Role.all.each_with_index {|role, i| role.update_attribute(:position, i+1)}
  end

  def self.down
    remove_column :roles, :position
  end
end
