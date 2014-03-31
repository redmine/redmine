class AddTimelogPermissions < ActiveRecord::Migration
  # model removed
  class Permission < ActiveRecord::Base; end

  def self.up
    Permission.create :controller => "timelog", :action => "edit", :description => "button_log_time", :sort => 1520, :is_public => false, :mail_option => 0, :mail_enabled => 0
  end

  def self.down
    Permission.where(:controller => "timelog", :action => "edit").each {|p| p.destroy}
  end
end
