class AddIndexOnMemberRolesInheritedFrom < ActiveRecord::Migration
  def change
    add_index :member_roles, :inherited_from
  end
end
