class AddMissingIndexesToIssueCategories < ActiveRecord::Migration[4.2]
  def self.up
    add_index :issue_categories, :assigned_to_id
  end

  def self.down
    remove_index :issue_categories, :assigned_to_id
  end
end
