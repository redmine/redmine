class AddProjectsDefaultVersionId < ActiveRecord::Migration[4.2]
  def self.up
    # Don't try to add the column if redmine_default_version plugin was used
    unless column_exists?(:projects, :default_version_id, :integer)
      add_column :projects, :default_version_id, :integer, :default => nil
    end
  end

  def self.down
    remove_column :projects, :default_version_id
  end
end
