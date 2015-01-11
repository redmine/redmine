# Redmine - project management software
# Copyright (C) 2006-2015  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

namespace :redmine do
  namespace :attachments do
    desc 'Removes uploaded files left unattached after one day.'
    task :prune => :environment do
      Attachment.prune
    end

    desc 'Moves attachments stored at the root of the file directory (ie. created before Redmine 2.3) to their subdirectories'
    task :move_to_subdirectories => :environment do
      Attachment.move_from_root_to_target_directory
    end
  end

  namespace :tokens do
    desc 'Removes expired tokens.'
    task :prune => :environment do
      Token.destroy_expired
    end
  end

  namespace :watchers do
    desc 'Removes watchers from what they can no longer view.'
    task :prune => :environment do
      Watcher.prune
    end
  end

  desc 'Fetch changesets from the repositories'
  task :fetch_changesets => :environment do
    Repository.fetch_changesets
  end

  desc 'Migrates and copies plugins assets.'
  task :plugins do
    Rake::Task["redmine:plugins:migrate"].invoke
    Rake::Task["redmine:plugins:assets"].invoke
  end

desc <<-DESC
FOR EXPERIMENTAL USE ONLY, Moves Redmine data from production database to the development database.
This task should only be used when you need to move data from one DBMS to a different one (eg. MySQL to PostgreSQL).
WARNING: All data in the development database is deleted.
DESC

  task :migrate_dbms => :environment do
    ActiveRecord::Base.establish_connection :development
    target_tables = ActiveRecord::Base.connection.tables
    ActiveRecord::Base.remove_connection

    ActiveRecord::Base.establish_connection :production
    tables = ActiveRecord::Base.connection.tables.sort - %w(schema_migrations plugin_schema_info)

    if (tables - target_tables).any?
      list = (tables - target_tables).map {|table| "* #{table}"}.join("\n")
      abort "The following table(s) are missing from the target database:\n#{list}"
    end

    tables.each do |table_name|
      Source = Class.new(ActiveRecord::Base)
      Target = Class.new(ActiveRecord::Base)
      Target.establish_connection(:development)

      [Source, Target].each do |klass|
        klass.table_name = table_name
        klass.reset_column_information
        klass.inheritance_column = "foo"
        klass.record_timestamps = false
      end
      Target.primary_key = (Target.column_names.include?("id") ? "id" : nil)

      source_count = Source.count
      puts "Migrating %6d records from #{table_name}..." % source_count

      Target.delete_all
      offset = 0
      while (objects = Source.offset(offset).limit(5000).order("1,2").to_a) && objects.any?
        offset += objects.size
        Target.transaction do
          objects.each do |object|
            new_object = Target.new(object.attributes)
            new_object.id = object.id if Target.primary_key
            new_object.save(:validate => false)
          end
        end
      end
      Target.connection.reset_pk_sequence!(table_name) if Target.primary_key
      target_count = Target.count
      abort "Some records were not migrated" unless source_count == target_count
    end
  end

  namespace :plugins do
    desc 'Migrates installed plugins.'
    task :migrate => :environment do
      name = ENV['NAME']
      version = nil
      version_string = ENV['VERSION']
      if version_string
        if version_string =~ /^\d+$/
          version = version_string.to_i
          if name.nil?
            abort "The VERSION argument requires a plugin NAME."
          end
        else
          abort "Invalid VERSION #{version_string} given."
        end
      end

      begin
        Redmine::Plugin.migrate(name, version)
      rescue Redmine::PluginNotFound
        abort "Plugin #{name} was not found."
      end

      Rake::Task["db:schema:dump"].invoke
    end

    desc 'Copies plugins assets into the public directory.'
    task :assets => :environment do
      name = ENV['NAME']

      begin
        Redmine::Plugin.mirror_assets(name)
      rescue Redmine::PluginNotFound
        abort "Plugin #{name} was not found."
      end
    end

    desc 'Runs the plugins tests.'
    task :test do
      Rake::Task["redmine:plugins:test:units"].invoke
      Rake::Task["redmine:plugins:test:functionals"].invoke
      Rake::Task["redmine:plugins:test:integration"].invoke
    end

    namespace :test do
      desc 'Runs the plugins unit tests.'
      Rake::TestTask.new :units => "db:test:prepare" do |t|
        t.libs << "test"
        t.verbose = true
        t.pattern = "plugins/#{ENV['NAME'] || '*'}/test/unit/**/*_test.rb"
      end

      desc 'Runs the plugins functional tests.'
      Rake::TestTask.new :functionals => "db:test:prepare" do |t|
        t.libs << "test"
        t.verbose = true
        t.pattern = "plugins/#{ENV['NAME'] || '*'}/test/functional/**/*_test.rb"
      end

      desc 'Runs the plugins integration tests.'
      Rake::TestTask.new :integration => "db:test:prepare" do |t|
        t.libs << "test"
        t.verbose = true
        t.pattern = "plugins/#{ENV['NAME'] || '*'}/test/integration/**/*_test.rb"
      end
    end
  end
end

# Load plugins' rake tasks
Dir[File.join(Rails.root, "plugins/*/lib/tasks/**/*.rake")].sort.each { |ext| load ext }
