class AddRolesAllRolesManaged < ActiveRecord::Migration[4.2]
  def change
    add_column :roles, :all_roles_managed, :boolean, :default => true, :null => false
  end
end
