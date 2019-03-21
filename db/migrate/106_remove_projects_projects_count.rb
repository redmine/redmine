class RemoveProjectsProjectsCount < ActiveRecord::Migration[4.2]
  def self.up
    remove_column :projects, :projects_count
  end

  def self.down
    add_column :projects, :projects_count, :integer, :default => 0
  end
end
