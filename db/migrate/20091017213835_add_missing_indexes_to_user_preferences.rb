class AddMissingIndexesToUserPreferences < ActiveRecord::Migration[4.2]
  def self.up
    add_index :user_preferences, :user_id
  end

  def self.down
    remove_index :user_preferences, :user_id
  end
end
