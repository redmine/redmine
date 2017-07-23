class AddRelationsPermissions < ActiveRecord::Migration[4.2]
  # model removed
  class Permission < ActiveRecord::Base; end

  def self.up
    Permission.create :controller => "issue_relations", :action => "new", :description => "label_relation_new", :sort => 1080, :is_public => false, :mail_option => 0, :mail_enabled => 0
    Permission.create :controller => "issue_relations", :action => "destroy", :description => "label_relation_delete", :sort => 1085, :is_public => false, :mail_option => 0, :mail_enabled => 0
  end

  def self.down
    Permission.where(:controller => "issue_relations", :action => "new").each {|p| p.destroy}
    Permission.where(:controller => "issue_relations", :action => "destroy").each {|p| p.destroy}
  end
end
