class AddProjectsDefaultIssueQueryId < ActiveRecord::Migration[4.2]
  def self.up
    add_column :projects, :default_issue_query_id, :integer, :default => nil
  end

  def self.down
    remove_column :projects, :default_issue_query_id
  end
end
