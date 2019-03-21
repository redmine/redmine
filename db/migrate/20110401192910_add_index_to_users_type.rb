class AddIndexToUsersType < ActiveRecord::Migration[4.2]
  def self.up
    add_index :users, :type
  end

  def self.down
    remove_index :users, :type
  end
end
