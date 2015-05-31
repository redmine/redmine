class CreateRolesManagedRoles < ActiveRecord::Migration
  def change
    create_table :roles_managed_roles, :id => false do |t|
      t.integer :role_id, :null => false
      t.integer :managed_role_id, :null => false
    end
  end
end
