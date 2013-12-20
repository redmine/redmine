class SetDocAndFilesNotifications < ActiveRecord::Migration
  # model removed
  class Permission < ActiveRecord::Base; end

  def self.up
    Permission.where(:controller => "projects", :action => "add_file").each {|p| p.update_attribute(:mail_option, true)}
    Permission.where(:controller => "projects", :action => "add_document").each {|p| p.update_attribute(:mail_option, true)}
    Permission.where(:controller => "documents", :action => "add_attachment").each {|p| p.update_attribute(:mail_option, true)}
    Permission.where(:controller => "issues", :action => "add_attachment").each {|p| p.update_attribute(:mail_option, true)}
  end

  def self.down
    Permission.where(:controller => "projects", :action => "add_file").each {|p| p.update_attribute(:mail_option, false)}
    Permission.where(:controller => "projects", :action => "add_document").each {|p| p.update_attribute(:mail_option, false)}
    Permission.where(:controller => "documents", :action => "add_attachment").each {|p| p.update_attribute(:mail_option, false)}
    Permission.where(:controller => "issues", :action => "add_attachment").each {|p| p.update_attribute(:mail_option, false)}
  end
end
