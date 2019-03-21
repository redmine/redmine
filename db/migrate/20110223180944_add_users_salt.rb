class AddUsersSalt < ActiveRecord::Migration[4.2]
  def self.up
    add_column :users, :salt, :string, :limit => 64
  end

  def self.down
    remove_column :users, :salt
  end
end
