class BuildProjectsTree < ActiveRecord::Migration
  def self.up
    Project.rebuild!(false)
  end

  def self.down
  end
end
