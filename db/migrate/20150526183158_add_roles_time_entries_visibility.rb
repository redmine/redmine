class AddRolesTimeEntriesVisibility < ActiveRecord::Migration
  def self.up
    add_column :roles, :time_entries_visibility, :string, :limit => 30, :default => 'all', :null => false
  end

  def self.down
    remove_column :roles, :time_entries_visibility
  end
end
