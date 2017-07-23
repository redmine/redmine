class ChangeTimeEntriesCommentsLimitTo1024 < ActiveRecord::Migration[4.2]
  def self.up
    change_column :time_entries, :comments, :string, :limit => 1024
  end

  def self.down
    change_column :time_entries, :comments, :string, :limit => 255
  end
end
