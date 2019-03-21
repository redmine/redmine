class AddViewIssuesPermission < ActiveRecord::Migration[4.2]
  def self.up
    Role.reset_column_information
    Role.all.each do |r|
      r.add_permission!(:view_issues)
    end
  end

  def self.down
    Role.reset_column_information
    Role.all.each do |r|
      r.remove_permission!(:view_issues)
    end
  end
end
