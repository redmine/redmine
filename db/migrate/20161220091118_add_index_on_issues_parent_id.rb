class AddIndexOnIssuesParentId < ActiveRecord::Migration
  def change
    add_index :issues, :parent_id
  end
end
