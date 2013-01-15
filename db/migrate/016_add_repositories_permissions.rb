class AddRepositoriesPermissions < ActiveRecord::Migration
  # model removed
  class Permission < ActiveRecord::Base; end

  def self.up
    Permission.create :controller => "repositories", :action => "show", :description => "button_view", :sort => 1450, :is_public => true
    Permission.create :controller => "repositories", :action => "browse", :description => "label_browse", :sort => 1460, :is_public => true
    Permission.create :controller => "repositories", :action => "entry", :description => "entry", :sort => 1462, :is_public => true
    Permission.create :controller => "repositories", :action => "revisions", :description => "label_view_revisions", :sort => 1470, :is_public => true
    Permission.create :controller => "repositories", :action => "revision", :description => "label_view_revisions", :sort => 1472, :is_public => true
    Permission.create :controller => "repositories", :action => "diff", :description => "diff", :sort => 1480, :is_public => true
  end

  def self.down
    Permission.where("controller=? and action=?", 'repositories', 'show').first.destroy
    Permission.where("controller=? and action=?", 'repositories', 'browse').first.destroy
    Permission.where("controller=? and action=?", 'repositories', 'entry').first.destroy
    Permission.where("controller=? and action=?", 'repositories', 'revisions').first.destroy
    Permission.where("controller=? and action=?", 'repositories', 'revision').first.destroy
    Permission.where("controller=? and action=?", 'repositories', 'diff').first.destroy
  end
end
