class AddProjectsFeedsPermissions < ActiveRecord::Migration[4.2]
  # model removed
  class Permission < ActiveRecord::Base; end

  def self.up
    Permission.create :controller => "projects", :action => "feeds", :description => "label_feed_plural", :sort => 132, :is_public => true, :mail_option => 0, :mail_enabled => 0
  end

  def self.down
    Permission.where(:controller => "projects", :action => "feeds").each {|p| p.destroy}
  end
end
