class AddIssueCategoriesAssignedToId < ActiveRecord::Migration[4.2]
  def self.up
    add_column :issue_categories, :assigned_to_id, :integer
  end

  def self.down
    remove_column :issue_categories, :assigned_to_id
  end
end
