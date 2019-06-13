# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2019  Jean-Philippe Lang
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
