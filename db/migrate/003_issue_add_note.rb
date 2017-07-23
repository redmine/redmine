class IssueAddNote < ActiveRecord::Migration[4.2]
  # model removed
  class Permission < ActiveRecord::Base; end

  def self.up
    Permission.create :controller => "issues", :action => "add_note", :description => "label_add_note", :sort => 1057, :mail_option => 1, :mail_enabled => 0
  end

  def self.down
    Permission.where("controller=? and action=?", 'issues', 'add_note').first.destroy
  end
end
