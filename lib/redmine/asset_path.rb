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
  class AssetPath
    attr_reader :paths, :prefix, :version

    def initialize(base_dir, paths, prefix=nil)
      @base_dir = base_dir
      @paths  = paths
      @prefix = prefix
      @transition = Transition.new(src: Set.new, dest: Set.new)
      @version = Rails.application.config.assets.version
    end

    def update(transition_map:, assets:, load_path:)
      each_file do |file, intermediate_path, logical_path|
        @transition.add_src  intermediate_path, logical_path
        @transition.add_dest intermediate_path, logical_path
        asset = if file.extname == '.css'
                  Redmine::Asset.new(file,   logical_path: logical_path, load_path: load_path, transition_map: transition_map)
                else
                  Propshaft::Asset.new(file, logical_path: logical_path, load_path: load_path)
                end
        assets[asset.logical_path.to_s] ||= asset
      end
      @transition.update(transition_map)
      nil
    end

    def each_file
      paths.each do |path|
        without_dotfiles(all_files_from_tree(path)).each do |file|
          relative_path = file.relative_path_from(path).to_s
          logical_path  = prefix ? File.join(prefix, relative_path) : relative_path
          intermediate_path = Pathname.new("/#{prefix}").join(file.relative_path_from(@base_dir))
          yield file, intermediate_path, logical_path
        end
      end
    end

    private

    Transition = Struct.new(:src, :dest, keyword_init: true) do
      def add_src(file, logical_path)
        src.add  path_pair(file, logical_path) if file.extname == '.css'
      end

      def add_dest(file, logical_path)
        return if file.extname == '.js' || file.extname == '.map'

        # No parent-child directories are needed in dest.
        dirname = file.dirname
        if child = dest.find{|d| child_path? dirname, d[0]}
          dest.delete child
          dest.add path_pair(file, logical_path)
        elsif !dest.any?{|d| parent_path? dirname, d[0]}
          dest.add path_pair(file, logical_path)
        end
      end

      def path_pair(file, logical_path)
        [file.dirname, Pathname.new("/#{logical_path}").dirname]
      end

      def parent_path?(path, other)
        return false if other == path

        path.ascend.any?(other)
      end

      def child_path?(path, other)
        return false if path == other

        other.ascend.any?(path)
      end

      def update(transition_map)
        product = src.to_a.product(dest.to_a).select{|t| t[0] != t[1]}
        maps = product.map do |t|
          AssetPathMap.new(src: t[0][0], dest: t[1][0], logical_src: t[0][1], logical_dest: t[1][1])
        end
        maps.each do |m|
          if m.before != m.after
            transition_map[m.dirname] ||= {}
            transition_map[m.dirname][m.before] = m.after
          end
        end
      end
    end

    AssetPathMap = Struct.new(:src, :dest, :logical_src, :logical_dest, keyword_init: true) do
      def dirname
        key = logical_src.to_s.sub('/', '')
        key == '' ? '.' : key
      end

      def before
        dest.relative_path_from(src).to_s
      end

      def after
        logical_dest.relative_path_from(logical_src).to_s
      end
    end

    def without_dotfiles(files)
      files.reject { |file| file.basename.to_s.starts_with?(".") }
    end

    def all_files_from_tree(path)
      path.children.flat_map { |child| child.directory? ? all_files_from_tree(child) : child }
    end
  end

  class AssetLoadPath < Propshaft::LoadPath
    attr_reader :extension_paths, :default_asset_path, :transition_map

    def initialize(config, compilers)
      @extension_paths    = config.redmine_extension_paths
      @default_asset_path = config.redmine_default_asset_path
      super(config.paths, compilers: compilers, version: config.version)
    end

    def asset_files
      Enumerator.new do |y|
        Rails.logger.info all_paths
        all_paths.each do |path|
          next unless path.exist?

          without_dotfiles(all_files_from_tree(path)).each do |file|
            y << file
          end
        end
      end
    end

    def assets_by_path
      merge_required = @cached_assets_by_path.nil?
      super
      if merge_required
        @transition_map = {}
        default_asset_path.update(assets: @cached_assets_by_path, transition_map: transition_map, load_path: self)
        extension_paths.each do |asset_path|
          # Support link from extension assets to assets in the application
          default_asset_path.each_file do |file, intermediate_path, logical_path|
            asset_path.instance_eval { @transition.add_dest intermediate_path, logical_path }
          end
          asset_path.update(assets: @cached_assets_by_path, transition_map: transition_map, load_path: self)
        end
      end
      @cached_assets_by_path
    end

    def cache_sweeper
      @cache_sweeper ||= begin
        exts_to_watch  = Mime::EXTENSION_LOOKUP.map(&:first)
        files_to_watch = Array(all_paths).to_h { |dir| [dir.to_s, exts_to_watch] }
        Rails.application.config.file_watcher.new([], files_to_watch) do
          clear_cache
        end
      end
    end

    def all_paths
      [paths, default_asset_path.paths, extension_paths.map{|path| path.paths}].flatten.compact
    end

    def clear_cache
      @transition_map = nil
      super
    end
  end

  class Asset < Propshaft::Asset
    def initialize(file, logical_path:, load_path:, transition_map:)
      @transition_map = transition_map
      super(file, logical_path: logical_path, load_path: load_path)
    end

    def content
      if conversion = @transition_map[logical_path.dirname.to_s]
        convert_path super, conversion
      else
        super
      end
    end

    ASSET_URL_PATTERN = /(url\(\s*["']?([^"'\s)]+)\s*["']?\s*\))/ unless defined? ASSET_URL_PATTERN

    def convert_path(input, conversion)
      input.gsub(ASSET_URL_PATTERN) do |matched|
        conversion.each do |key, val|
          matched.sub!(key, val)
        end
        matched
      end
    end
  end
end
