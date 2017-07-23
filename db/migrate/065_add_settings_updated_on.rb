class AddSettingsUpdatedOn < ActiveRecord::Migration[4.2]
  def self.up
    add_column :settings, :updated_on, :timestamp
    # set updated_on
    Setting.all.each(&:save)
  end

  def self.down
    remove_column :settings, :updated_on
  end
end
