class AddSearchPermission < ActiveRecord::Migration
  # model removed
  class Permission < ActiveRecord::Base; end

  def self.up
    Permission.create :controller => "projects", :action => "search", :description => "label_search", :sort => 130, :is_public => true, :mail_option => 0, :mail_enabled => 0
  end

  def self.down
    Permission.where(:controller => "projects", :action => "search").each {|p| p.destroy}
  end
end
