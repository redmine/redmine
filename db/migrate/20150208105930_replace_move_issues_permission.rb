class ReplaceMoveIssuesPermission < ActiveRecord::Migration[4.2]
  def self.up
    Role.all.each do |role|
      if role.has_permission?(:edit_issues) && !role.has_permission?(:move_issues)
        # inserts one ligne per trakcer and status
        rule = WorkflowPermission.connection.quote_column_name('rule') # rule is a reserved keyword in SQLServer
        WorkflowPermission.connection.execute(
          "INSERT INTO #{WorkflowPermission.table_name} (tracker_id, old_status_id, role_id, type, field_name, #{rule})" +
          " SELECT t.id, s.id, #{role.id}, 'WorkflowPermission', 'project_id', 'readonly'" +
          " FROM #{Tracker.table_name} t, #{IssueStatus.table_name} s"
        )
      end
    end
  end

  def self.down
    raise IrreversibleMigration
  end
end
