class ChangeUsersMailNotificationToString < ActiveRecord::Migration[4.2]
  def self.up
    rename_column :users, :mail_notification, :mail_notification_bool
    add_column :users, :mail_notification, :string, :default => '', :null => false
    User.where("mail_notification_bool = #{connection.quoted_true}").
      update_all("mail_notification = 'all'")
    User.where("EXISTS (SELECT 1 FROM #{Member.table_name} WHERE #{Member.table_name}.mail_notification = #{connection.quoted_true} AND #{Member.table_name}.user_id = #{User.table_name}.id)").
      update_all("mail_notification = 'selected'")
    User.where("mail_notification NOT IN ('all', 'selected')").
      update_all("mail_notification = 'only_my_events'")
    remove_column :users, :mail_notification_bool
  end

  def self.down
    rename_column :users, :mail_notification, :mail_notification_char
    add_column :users, :mail_notification, :boolean, :default => true, :null => false
    User.where("mail_notification_char <> 'all'").
      update_all("mail_notification = #{connection.quoted_false}")
    remove_column :users, :mail_notification_char
  end
end
