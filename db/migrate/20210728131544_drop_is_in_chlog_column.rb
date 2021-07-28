class DropIsInChlogColumn < ActiveRecord::Migration[6.1]
  def self.up
    remove_column :trackers, :is_in_chlog
  end

  def self.down
    add_column :trackers, :is_in_chlog, :boolean, :default => true, :null => false
  end
end
