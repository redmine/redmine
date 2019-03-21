class AddMemberRolesInheritedFrom < ActiveRecord::Migration[4.2]
  def self.up
    add_column :member_roles, :inherited_from, :integer
  end

  def self.down
    remove_column :member_roles, :inherited_from
  end
end
