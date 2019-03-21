class AddMissingIndexesToUsers < ActiveRecord::Migration[4.2]
  def self.up
    add_index :users, [:id, :type]
    add_index :users, :auth_source_id
  end

  def self.down
    remove_index :users, :column => [:id, :type]
    remove_index :users, :auth_source_id
  end
end
