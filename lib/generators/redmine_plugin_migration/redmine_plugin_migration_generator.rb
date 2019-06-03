class RedminePluginMigrationGenerator < Rails::Generators::NamedBase
  include Rails::Generators::Migration

  source_root File.expand_path("../templates", __FILE__)
  argument :migration, :type => :string

  class << self
    def next_migration_number(dirname)
      next_migration_number = current_migration_number(dirname) + 1
      ActiveRecord::Migration.next_migration_number(next_migration_number)
    end
  end

  def create_migration_file
    plugin_name = file_name.underscore
    plugin_path = File.join(Redmine::Plugin.directory, plugin_name)
    migration_template "migration.rb",
                       "#{plugin_path}/db/migrate/#{@migration}.rb"
  end
end
