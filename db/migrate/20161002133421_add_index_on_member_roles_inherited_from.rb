class AddIndexOnMemberRolesInheritedFrom < ActiveRecord::Migration[4.2]
  def change
    add_index :member_roles, :inherited_from
  end
end
