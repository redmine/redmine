class AddRepositoriesChangesPermission < ActiveRecord::Migration[4.2]
  # model removed
  class Permission < ActiveRecord::Base; end

  def self.up
    Permission.create :controller => 'repositories', :action => 'changes', :description => 'label_change_plural', :sort => 1475, :is_public => true, :mail_option => 0, :mail_enabled => 0
  end

  def self.down
    Permission.where(:controller => "repositories", :action => "changes").each {|p| p.destroy}
  end
end
