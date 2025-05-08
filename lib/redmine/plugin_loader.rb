# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-  Jean-Philippe Lang
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

module Redmine
  class PluginPath
    attr_reader :assets_dir, :initializer

    def initialize(dir)
      @dir = dir
      @assets_dir = File.join dir, 'assets'
      @initializer = File.join dir, 'init.rb'
    end

    def run_initializer
      load initializer if has_initializer?
    end

    def to_s
      @dir
    end

    def has_assets_dir?
      File.directory?(@assets_dir)
    end

    def has_initializer?
      File.file?(@initializer)
    end
  end

  class PluginLoader
    # Absolute path to the directory where plugins are located
    cattr_accessor :directory
    self.directory = Rails.root.join Rails.application.config.redmine_plugins_directory

    # Absolute path to the public directory where plugins assets are copied
    cattr_accessor :public_directory
    self.public_directory = Rails.public_path.join('plugin_assets')

    def self.load
      setup
      add_autoload_paths

      Rails.application.config.to_prepare do
        PluginLoader.directories.each(&:run_initializer)

        Redmine::Hook.call_hook :after_plugins_loaded
      end
    end

    def self.setup
      @plugin_directories = []

      Dir.glob(File.join(directory, '*')).each do |directory|
        next unless File.directory?(directory)

        @plugin_directories << PluginPath.new(directory)
      end
    end

    def self.add_autoload_paths
      directories.each do |directory|
        # Add the plugin directories to rails autoload paths
        engine_cfg = Rails::Engine::Configuration.new(directory.to_s)
        engine_cfg.paths.add 'lib', eager_load: true
        engine_cfg.all_eager_load_paths.each do |dir|
          Rails.autoloaders.main.push_dir dir
          Rails.application.config.watchable_dirs[dir] = [:rb]
        end
      end
    end

    def self.directories
      @plugin_directories
    end
  end
end
