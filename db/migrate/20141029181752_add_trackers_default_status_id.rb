class AddTrackersDefaultStatusId < ActiveRecord::Migration[4.2]
  def up
    add_column :trackers, :default_status_id, :integer

    status_id = IssueStatus.where(:is_default => true).pick(:id)
    status_id ||= IssueStatus.order(:position).pick(:id)
    if status_id
      Tracker.update_all :default_status_id => status_id
    end
  end

  def down
    remove_column :trackers, :default_status_id
  end
end
