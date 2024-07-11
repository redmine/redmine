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
  module Themes
    # Return an array of installed themes
    def self.themes
      @@installed_themes ||= scan_themes
    end

    # Rescan themes directory
    def self.rescan
      @@installed_themes = scan_themes
    end

    # Return theme for given id, or nil if it's not found
    def self.theme(id, options={})
      return nil if id.blank?

      found = themes.find {|t| t.id == id}
      if found.nil? && options[:rescan] != false
        rescan
        found = theme(id, :rescan => false)
      end
      found
    end

    # Class used to represent a theme
    class Theme
      attr_reader :path, :name, :dir

      def initialize(path)
        @path = path
        @dir = File.basename(path)
        @name = @dir.humanize
        @stylesheets = nil
        @javascripts = nil
      end

      # Directory name used as the theme id
      def id; dir end

      def ==(theme)
        theme.is_a?(Theme) && theme.dir == dir
      end

      def <=>(theme)
        return nil unless theme.is_a?(Theme)

        name <=> theme.name
      end

      def stylesheets
        @stylesheets ||= assets("stylesheets", "css")
      end

      def images
        @images ||= assets("images")
      end

      def javascripts
        @javascripts ||= assets("javascripts", "js")
      end

      def favicons
        @favicons ||= assets("favicon")
      end

      def favicon
        favicons.first
      end

      def favicon?
        favicon.present?
      end

      def stylesheet_path(source)
        "#{asset_prefix}#{source}"
      end

      def image_path(source)
        "#{asset_prefix}#{source}"
      end

      def javascript_path(source)
        "#{asset_prefix}#{source}"
      end

      def favicon_path
        "#{asset_prefix}#{favicon}"
      end

      def asset_prefix
        "themes/#{dir}/"
      end

      def asset_paths
        base_dir = Pathname.new(path)
        paths = base_dir.children.select do |child|
          child.directory? &&
            child.basename.to_s != 'src' &&
            !child.basename.to_s.start_with?('.')
        end
        Redmine::AssetPath.new(base_dir, paths, asset_prefix)
      end

      private

      def assets(dir, ext=nil)
        if ext
          Dir.glob("#{path}/#{dir}/*.#{ext}").collect {|f| File.basename(f, ".#{ext}")}
        else
          Dir.glob("#{path}/#{dir}/*").collect {|f| File.basename(f)}
        end
      end
    end

    module Helper
      def current_theme
        unless instance_variable_defined?(:@current_theme)
          @current_theme = Redmine::Themes.theme(Setting.ui_theme)
        end
        @current_theme
      end

      # Returns the header tags for the current theme
      def heads_for_theme
        if current_theme && current_theme.javascripts.include?('theme')
          javascript_include_tag current_theme.javascript_path('theme')
        end
      end
    end

    def self.scan_themes
      dirs = Dir.glob(["#{Rails.root}/app/assets/themes/*", "#{Rails.root}/themes/*"]).select do |f|
        # A theme should at least override application.css
        File.directory?(f) && File.exist?("#{f}/stylesheets/application.css")
      end
      dirs.collect {|dir| Theme.new(dir)}.sort
    end
    private_class_method :scan_themes
  end
end
