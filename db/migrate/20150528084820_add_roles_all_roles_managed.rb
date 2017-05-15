class AddRolesAllRolesManaged < ActiveRecord::Migration
  def change
    add_column :roles, :all_roles_managed, :boolean, :default => true, :null => false
  end
end
