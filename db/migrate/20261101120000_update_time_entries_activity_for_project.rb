class UpdateTimeEntriesActivityForProject < ActiveRecord::Migration[8.1]
  def up
    overrides = TimeEntryActivity.where.not(project_id: nil).where.not(parent_id: nil).pluck(:id, :project_id, :parent_id)
    return if overrides.empty?

    shared_activity_ids = overrides.to_h {|id, _project_id, parent_id| [id, parent_id]}
    override_ids = overrides.to_h {|id, project_id, parent_id| [[project_id, parent_id], id]}

    TimeEntry.distinct.pluck(:project_id, :activity_id).each do |project_id, activity_id|
      shared_activity_id = shared_activity_ids[activity_id] || activity_id
      new_activity_id = override_ids[[project_id, shared_activity_id]] || shared_activity_id
      next if new_activity_id == activity_id

      TimeEntry.where(project_id: project_id, activity_id: activity_id).update_all(activity_id: new_activity_id)
    end
  end

  def down
    # no-op
  end
end
