class AddExportIssuesAndExportTimeEntriesPermissions < ActiveRecord::Migration[8.1]
  def up
    Role.find_each do |role|
      role.add_permission!(:export_issues) if role.has_permission?(:view_issues)
      role.add_permission!(:export_time_entries) if role.has_permission?(:view_time_entries)
    end
  end

  def down
    Role.find_each do |role|
      role.remove_permission!(:export_issues, :export_time_entries)
    end
  end
end
