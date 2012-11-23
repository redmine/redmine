class BuildProjectsTree < ActiveRecord::Migration
  def self.up
    Project.rebuild_tree!
  end

  def self.down
  end
end
