class AddCommentsPermissions < ActiveRecord::Migration[4.2]
  # model removed
  class Permission < ActiveRecord::Base; end

  def self.up
    Permission.create :controller => "news", :action => "add_comment", :description => "label_comment_add", :sort => 1130, :is_public => false, :mail_option => 0, :mail_enabled => 0
    Permission.create :controller => "news", :action => "destroy_comment", :description => "label_comment_delete", :sort => 1133, :is_public => false, :mail_option => 0, :mail_enabled => 0
  end

  def self.down
    Permission.where("controller=? and action=?", 'news', 'add_comment').first.destroy
    Permission.where("controller=? and action=?", 'news', 'destroy_comment').first.destroy
  end
end
