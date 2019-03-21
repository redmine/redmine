class BuildProjectsTree < ActiveRecord::Migration[4.2]
  def self.up
    Project.rebuild_tree!
  end

  def self.down
  end
end
