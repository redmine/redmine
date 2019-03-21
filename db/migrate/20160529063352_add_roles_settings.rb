class AddRolesSettings < ActiveRecord::Migration[4.2]
  def change
    add_column :roles, :settings, :text
  end
end
