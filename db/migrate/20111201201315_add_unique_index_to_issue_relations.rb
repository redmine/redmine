class AddUniqueIndexToIssueRelations < ActiveRecord::Migration
  def self.up

    # Remove duplicates
    IssueRelation.connection.select_values("SELECT r.id FROM #{IssueRelation.table_name} r" +
      " WHERE r.id > (SELECT min(r1.id) FROM #{IssueRelation.table_name} r1 WHERE r1.issue_from_id = r.issue_from_id AND r1.issue_to_id = r.issue_to_id)").each do |i|
        IssueRelation.delete_all(["id = ?", i])
    end

    add_index :issue_relations, [:issue_from_id, :issue_to_id], :unique => true
  end

  def self.down
    remove_index :issue_relations, :column => [:issue_from_id, :issue_to_id]
  end
end
