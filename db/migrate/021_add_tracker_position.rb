class AddTrackerPosition < ActiveRecord::Migration[4.2]
  def self.up
    add_column :trackers, :position, :integer, :default => 1
    Tracker.all.each_with_index {|tracker, i| tracker.update_attribute(:position, i+1)}
  end

  def self.down
    remove_column :trackers, :position
  end
end
