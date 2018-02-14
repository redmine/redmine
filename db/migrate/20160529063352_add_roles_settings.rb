class AddRolesSettings < ActiveRecord::Migration
  def change
    add_column :roles, :settings, :text
  end
end