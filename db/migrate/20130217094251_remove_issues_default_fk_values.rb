class RemoveIssuesDefaultFkValues < ActiveRecord::Migration[4.2]
  def up
    change_column_default :issues, :tracker_id, nil
    change_column_default :issues, :project_id, nil
    change_column_default :issues, :status_id, nil
    change_column_default :issues, :assigned_to_id, nil
    change_column_default :issues, :priority_id, nil
    change_column_default :issues, :author_id, nil
  end

  def down
    change_column_default :issues, :tracker_id, 0
    change_column_default :issues, :project_id, 0
    change_column_default :issues, :status_id, 0
    change_column_default :issues, :assigned_to_id, 0
    change_column_default :issues, :priority_id, 0
    change_column_default :issues, :author_id, 0
  end
end
