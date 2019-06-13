class ChangeCustomValuesValueLimit < ActiveRecord::Migration[5.2]
  def up
    if Redmine::Database.mysql?
      max_size = 16.megabytes
      change_column :custom_values, :value, :text, :limit => max_size
    end
  end

  def down
    # no-op
  end
end
