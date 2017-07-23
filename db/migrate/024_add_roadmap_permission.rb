class AddRoadmapPermission < ActiveRecord::Migration[4.2]
  # model removed
  class Permission < ActiveRecord::Base; end

  def self.up
    Permission.create :controller => "projects", :action => "roadmap", :description => "label_roadmap", :sort => 107, :is_public => true, :mail_option => 0, :mail_enabled => 0
  end

  def self.down
    Permission.where("controller=? and action=?", 'projects', 'roadmap').first.destroy
  end
end
