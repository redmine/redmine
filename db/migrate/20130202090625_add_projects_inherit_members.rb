class AddProjectsInheritMembers < ActiveRecord::Migration
  def up
    add_column :projects, :inherit_members, :boolean, :default => false, :null => false
  end

  def down
    remove_column :projects, :inherit_members
  end
end
