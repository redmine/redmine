class RemoveIssueStatusesIsDefault < ActiveRecord::Migration[4.2]
  def up
    remove_column :issue_statuses, :is_default
  end

  def down
    add_column :issue_statuses, :is_default, :boolean, :null => false, :default => false
    # Restores the first status as default
    default_status_id = IssueStatus.order(:position).pluck(:id).first
    IssueStatus.where(:id => default_status_id).update_all(:is_default => true)
  end
end
