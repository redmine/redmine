# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2022  Jean-Philippe Lang
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

    def mirror_assets
      return unless has_assets_dir?

      destination = File.join(PluginLoader.public_directory, File.basename(@dir))

      source_files = Dir["#{assets_dir}/**/*"]
      source_dirs = source_files.select { |d| File.directory?(d)}
      source_files -= source_dirs
      unless source_files.empty?
        base_target_dir = File.join(destination, File.dirname(source_files.first).gsub(assets_dir, ''))
        begin
          FileUtils.mkdir_p(base_target_dir)
        rescue => e
          raise "Could not create directory #{base_target_dir}: " + e.message
        end
      end

      source_dirs.each do |dir|
        # strip down these paths so we have simple, relative paths we can
        # add to the destination
        target_dir = File.join(destination, dir.gsub(assets_dir, ''))
        begin
          FileUtils.mkdir_p(target_dir)
        rescue => e
          raise "Could not create directory #{target_dir}: " + e.message
        end
      end
      source_files.each do |file|
        target = File.join(destination, file.gsub(assets_dir, ''))
        unless File.exist?(target) && FileUtils.identical?(file, target)
          FileUtils.cp(file, target)
        end
      rescue => e
        raise "Could not copy #{file} to #{target}: " + e.message
      end
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
    self.directory = Rails.root.join('plugins')

    # Absolute path to the plublic directory where plugins assets are copied
    cattr_accessor :public_directory
    self.public_directory = Rails.root.join('public/plugin_assets')

    def self.create_assets_reloader
      plugin_assets_dirs = {}
      directories.each do |dir|
        plugin_assets_dirs[dir.assets_dir] = ['*']
      end
      ActiveSupport::FileUpdateChecker.new([], plugin_assets_dirs) do
        mirror_assets
      end
    end

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

      Dir.glob(File.join(directory, '*')).sort.each do |directory|
        next unless File.directory?(directory)

        @plugin_directories << PluginPath.new(directory)
      end
    end

    def self.add_autoload_paths
      directories.each do |directory|
        # Add the plugin directories to rails autoload paths
        engine_cfg = Rails::Engine::Configuration.new(directory.to_s)
        engine_cfg.paths.add 'lib', eager_load: true
        engine_cfg.eager_load_paths.each do |dir|
          Rails.autoloaders.main.push_dir dir
        end
      end
    end

    def self.directories
      @plugin_directories
    end

    def self.mirror_assets(name=nil)
      if name.present?
        directories.find{|d| d.to_s == File.join(directory, name)}.mirror_assets
      else
        directories.each(&:mirror_assets)
      end
    end
  end
end
