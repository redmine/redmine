class AddIssuesEstimatedHours < ActiveRecord::Migration[4.2]
  def self.up
    add_column :issues, :estimated_hours, :float
  end

  def self.down
    remove_column :issues, :estimated_hours
  end
end
