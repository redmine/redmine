class AddDefaultTimeEntryActivityToRoles < ActiveRecord::Migration[6.1]
  def change
    add_column :roles, :default_time_entry_activity_id, :int
  end
end
