class AddIndexOnChangesetsIssuesIssueId < ActiveRecord::Migration[4.2]
  def change
    add_index :changesets_issues, :issue_id
  end
end
