class ChangeUsersLastnameLengthTo255 < ActiveRecord::Migration[4.2]
  def self.up
    change_column :users, :lastname, :string, :limit => 255, :default => '', :null => false
  end

  def self.down
    change_column :users, :lastname, :string, :limit => 30, :default => '', :null => false
  end
end
