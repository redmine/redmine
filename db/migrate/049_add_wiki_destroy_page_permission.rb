class AddWikiDestroyPagePermission < ActiveRecord::Migration[4.2]
  # model removed
  class Permission < ActiveRecord::Base; end

  def self.up
    Permission.create :controller => 'wiki', :action => 'destroy', :description => 'button_delete', :sort => 1740, :is_public => false, :mail_option => 0, :mail_enabled => 0
  end

  def self.down
    Permission.where(:controller => "wiki", :action => "destroy").each {|p| p.destroy}
  end
end
