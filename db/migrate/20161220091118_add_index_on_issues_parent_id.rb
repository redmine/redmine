class AddIndexOnIssuesParentId < ActiveRecord::Migration[4.2]
  def change
    add_index :issues, :parent_id
  end
end
