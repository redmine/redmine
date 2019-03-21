class IssueStartDate < ActiveRecord::Migration[4.2]
  def self.up
    add_column :issues, :start_date, :date
    add_column :issues, :done_ratio, :integer, :default => 0, :null => false
  end

  def self.down
    remove_column :issues, :start_date
    remove_column :issues, :done_ratio
  end
end
