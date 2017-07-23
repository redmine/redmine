class AddUserPreferencesTimeZone < ActiveRecord::Migration[4.2]
  def self.up
    add_column :user_preferences, :time_zone, :string
  end

  def self.down
    remove_column :user_preferences, :time_zone
  end
end
