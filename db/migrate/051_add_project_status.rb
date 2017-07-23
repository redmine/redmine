class AddProjectStatus < ActiveRecord::Migration[4.2]
  def self.up
    add_column :projects, :status, :integer, :default => 1, :null => false
  end

  def self.down
    remove_column :projects, :status
  end
end
