class ChangeSettingsValueLimit < ActiveRecord::Migration[7.2]
  def up
    if Redmine::Database.mysql?
      max_size = 16.megabytes
      change_column :settings, :value, :text, :limit => max_size
    end
  end

  def down
    # no-op
  end
end
