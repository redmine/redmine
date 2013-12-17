class CreateGithubIssues < ActiveRecord::Migration
  def change
    create_table :github_issues do |t|
      t.column :issue_number, :integer, :default => 0
      t.references :issue
    end
  end
end
