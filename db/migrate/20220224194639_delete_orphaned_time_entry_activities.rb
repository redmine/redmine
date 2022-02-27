class DeleteOrphanedTimeEntryActivities < ActiveRecord::Migration[6.1]
  def self.up
    TimeEntryActivity.left_outer_joins(:project).where(projects: {id: nil}).where.not(project_id: nil).delete_all
  end

  def self.down
    # no-op
  end
end
