class AddProjectsInheritMembers < ActiveRecord::Migration[4.2]
  def up
    add_column :projects, :inherit_members, :boolean, :default => false, :null => false
  end

  def down
    remove_column :projects, :inherit_members
  end
end
