class AddIndexToSettingsName < ActiveRecord::Migration[4.2]
  def self.up
    add_index :settings, :name
  end

  def self.down
    remove_index :settings, :name
  end
end
