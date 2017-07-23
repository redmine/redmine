class AddUniqueIndexOnRolesManagedRoles < ActiveRecord::Migration[4.2]
  def change
    add_index :roles_managed_roles, [:role_id, :managed_role_id], :unique => true
  end
end
