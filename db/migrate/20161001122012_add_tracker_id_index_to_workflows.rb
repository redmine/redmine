class AddTrackerIdIndexToWorkflows < ActiveRecord::Migration
  def self.up
    add_index :workflows, :tracker_id
  end

  def self.down
    remove_index :workflows, :tracker_id
  end
end
