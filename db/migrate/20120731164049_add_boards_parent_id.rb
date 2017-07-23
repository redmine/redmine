class AddBoardsParentId < ActiveRecord::Migration[4.2]
  def up
    add_column :boards, :parent_id, :integer
  end

  def down
    remove_column :boards, :parent_id
  end
end
