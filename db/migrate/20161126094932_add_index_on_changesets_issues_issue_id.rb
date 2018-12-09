class AddIndexOnChangesetsIssuesIssueId < ActiveRecord::Migration
  def change
    add_index :changesets_issues, :issue_id
  end
end
