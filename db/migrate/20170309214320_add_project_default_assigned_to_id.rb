class AddProjectDefaultAssignedToId < ActiveRecord::Migration[4.2]
  def up
    add_column :projects, :default_assigned_to_id, :integer, :default => nil
    # Try to copy existing settings from the plugin if redmine_default_assign plugin was used
    if column_exists?(:projects, :default_assignee_id, :integer)
      Project.update_all('default_assigned_to_id = default_assignee_id')
    end
  end

  def down
    remove_column :projects, :default_assigned_to_id
  end
end
