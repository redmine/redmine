class AddNewsCommentsCount < ActiveRecord::Migration[4.2]
  def self.up
    add_column :news, :comments_count, :integer, :default => 0, :null => false
  end

  def self.down
    remove_column :news, :comments_count
  end
end
