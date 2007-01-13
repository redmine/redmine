class CreateIssueRelations < ActiveRecord::Migration
  def self.up
    create_table :issue_relations do |t|
      # t.column :name, :string
    end
  end

  def self.down
    drop_table :issue_relations
  end
end
