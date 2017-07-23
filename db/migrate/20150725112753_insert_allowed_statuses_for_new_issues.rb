class InsertAllowedStatusesForNewIssues < ActiveRecord::Migration[4.2]
  def self.up
    # Adds the default status for all trackers and roles
    sql = "INSERT INTO #{WorkflowTransition.table_name} (tracker_id, old_status_id, new_status_id, role_id, type)" +
      " SELECT t.id, 0, t.default_status_id, r.id, 'WorkflowTransition'" +
      " FROM #{Tracker.table_name} t, #{Role.table_name} r"
    WorkflowTransition.connection.execute(sql)

    # Adds other statuses that are reachable with one transition
    # to preserve previous behaviour as default
    sql = "INSERT INTO #{WorkflowTransition.table_name} (tracker_id, old_status_id, new_status_id, role_id, type)" +
      " SELECT t.id, 0, w.new_status_id, w.role_id, 'WorkflowTransition'" +
      " FROM #{Tracker.table_name} t" +
      " JOIN #{IssueStatus.table_name} s on s.id = t.default_status_id" +
      " JOIN #{WorkflowTransition.table_name} w on w.tracker_id = t.id and w.old_status_id = s.id and w.type = 'WorkflowTransition'" +
      " WHERE w.new_status_id <> t.default_status_id"
    WorkflowTransition.connection.execute(sql)
  end

  def self.down
    WorkflowTransition.where(:old_status_id => 0).delete_all
  end
end
