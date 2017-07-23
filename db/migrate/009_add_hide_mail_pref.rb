class AddHideMailPref < ActiveRecord::Migration[4.2]
  def self.up
    add_column :user_preferences, :hide_mail, :boolean, :default => false
  end

  def self.down
    remove_column :user_preferences, :hide_mail
  end
end
