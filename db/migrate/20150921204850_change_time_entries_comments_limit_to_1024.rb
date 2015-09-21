class ChangeTimeEntriesCommentsLimitTo1024 < ActiveRecord::Migration
  def self.up
    change_column :time_entries, :comments, :string, :limit => 1024
  end

  def self.down
    change_column :time_entries, :comments, :string, :limit => 255
  end
end
