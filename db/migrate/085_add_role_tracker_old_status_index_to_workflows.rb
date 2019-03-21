class AddRoleTrackerOldStatusIndexToWorkflows < ActiveRecord::Migration[4.2]
  def self.up
    add_index :workflows, [:role_id, :tracker_id, :old_status_id], :name => :wkfs_role_tracker_old_status
  end

  def self.down
    remove_index(:workflows, :name => :wkfs_role_tracker_old_status); rescue
  end
end
