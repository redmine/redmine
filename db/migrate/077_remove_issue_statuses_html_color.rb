class RemoveIssueStatusesHtmlColor < ActiveRecord::Migration[4.2]
  def self.up
    remove_column :issue_statuses, :html_color
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
