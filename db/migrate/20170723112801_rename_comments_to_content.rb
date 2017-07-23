class RenameCommentsToContent < ActiveRecord::Migration[5.1]
  def change
    rename_column :comments, :comments, :content
  end
end
