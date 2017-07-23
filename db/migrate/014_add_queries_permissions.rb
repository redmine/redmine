class AddQueriesPermissions < ActiveRecord::Migration[4.2]
  # model removed
  class Permission < ActiveRecord::Base; end

  def self.up
    Permission.create :controller => "projects", :action => "add_query", :description => "button_create", :sort => 600, :is_public => false, :mail_option => 0, :mail_enabled => 0
  end

  def self.down
    Permission.where("controller=? and action=?", 'projects', 'add_query').first.destroy
  end
end
