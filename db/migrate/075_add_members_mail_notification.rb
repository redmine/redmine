class AddMembersMailNotification < ActiveRecord::Migration[4.2]
  def self.up
    add_column :members, :mail_notification, :boolean, :default => false, :null => false
  end

  def self.down
    remove_column :members, :mail_notification
  end
end
