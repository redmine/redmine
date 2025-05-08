class DeleteOrphanedTimeEntryActivities < ActiveRecord::Migration[6.1]
  def self.up
    TimeEntryActivity.where.missing(:project).where.not(project_id: nil).delete_all
  end

  def self.down
    # no-op
  end
end
