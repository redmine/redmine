class AddIndexOnIssuesNestedSet < ActiveRecord::Migration[4.2]
  def self.up
    add_index :issues, [:root_id, :lft, :rgt]
  end

  def self.down
    remove_index :issues, [:root_id, :lft, :rgt]
  end
end
