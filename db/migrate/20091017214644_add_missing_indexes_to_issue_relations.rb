class AddMissingIndexesToIssueRelations < ActiveRecord::Migration[4.2]
  def self.up
    add_index :issue_relations, :issue_from_id
    add_index :issue_relations, :issue_to_id
  end

  def self.down
    remove_index :issue_relations, :issue_from_id
    remove_index :issue_relations, :issue_to_id
  end
end
