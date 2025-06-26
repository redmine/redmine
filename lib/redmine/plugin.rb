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

  # Exception raised when a plugin cannot be found given its id.
  class PluginNotFound < StandardError; end

  # Exception raised when a plugin requirement is not met.
  class PluginRequirementError < StandardError; end

  # Base class for Redmine plugins.
  # Plugins are registered using the <tt>register</tt> class method that acts as the public constructor.
  #
  #   Redmine::Plugin.register :example do
  #     name 'Example plugin'
  #     author 'John Smith'
  #     description 'This is an example plugin for Redmine'
  #     version '0.0.1'
  #     settings :default => {'foo'=>'bar'}, :partial => 'settings/settings'
  #   end
  #
  # === Plugin attributes
  #
  # +settings+ is an optional attribute that let the plugin be configurable.
  # It must be a hash with the following keys:
  # * <tt>:default</tt>: default value for the plugin settings
  # * <tt>:partial</tt>: path of the configuration partial view, relative to the plugin <tt>app/views</tt> directory
  # Example:
  #   settings :default => {'foo'=>'bar'}, :partial => 'settings/settings'
  # In this example, the settings partial will be found here in the plugin directory: <tt>app/views/settings/_settings.rhtml</tt>.
  #
  # When rendered, the plugin settings value is available as the local variable +settings+
  #
  # See: http://www.redmine.org/projects/redmine/wiki/Plugin_Tutorial
  class Plugin
    # Absolute path to the directory where plugins are located
    cattr_accessor :directory
    self.directory = PluginLoader.directory

    # Absolute path to the plublic directory where plugins assets are copied
    cattr_accessor :public_directory
    self.public_directory = PluginLoader.public_directory

    @registered_plugins = {}
    @used_partials = {}

    attr_accessor :path

    class << self
      attr_reader :registered_plugins
      private :new

      def def_field(*names)
        class_eval do
          names.each do |name|
            define_method(name) do |*args|
              args.empty? ? instance_variable_get("@#{name}") : instance_variable_set("@#{name}", *args)
            end
          end
        end
      end
    end
    def_field :name, :description, :url, :author, :author_url, :version, :settings, :directory
    attr_reader :id

    # Plugin constructor: instanciates a new Redmine::Plugin with given +id+
    # and make it evaluate the given +block+
    #
    # Example
    #   Redmine::Plugin.register :example do
    #     name 'Example plugin'
    #     author 'John Smith'
    #     description 'This is an example plugin for Redmine'
    #     version '0.0.1'
    #     requires_redmine version_or_higher: '3.0.0'
    #   end
    def self.register(id, &block)
      p = new(id)
      p.instance_eval(&block)

      # Set a default name if it was not provided during registration
      p.name(id.to_s.humanize) if p.name.nil?
      # Set a default directory if it was not provided during registration
      p.directory(File.join(self.directory, id.to_s)) if p.directory.nil?

      unless File.directory?(p.directory)
        raise PluginNotFound, "Plugin not found. The directory for plugin #{p.id} should be #{p.directory}."
      end

      p.path = PluginLoader.directories.find {|d| d.to_s == p.directory}

      # Adds plugin locales if any
      # YAML translation files should be found under <plugin>/config/locales/
      Rails.application.config.i18n.load_path += Dir.glob(File.join(p.directory, 'config', 'locales', '*.yml'))

      # Prepends the app/views directory of the plugin to the view path
      view_path = File.join(p.directory, 'app', 'views')
      if File.directory?(view_path)
        ActionController::Base.prepend_view_path(view_path)
        ActionMailer::Base.prepend_view_path(view_path)
      end

      # Defines plugin setting if present
      if p.settings
        Setting.define_plugin_setting p
      end

      # Warn for potential settings[:partial] collisions
      if p.configurable?
        partial = p.settings[:partial]
        if @used_partials[partial]
          Rails.logger.warn(
            "WARNING: settings partial '#{partial}' is declared in '#{p.id}' plugin " \
              "but it is already used by plugin '#{@used_partials[partial]}'. " \
              "Only one settings view will be used. " \
              "You may want to contact those plugins authors to fix this."
          )
        end
        @used_partials[partial] = p.id
      end

      registered_plugins[id] = p
    end

    # Returns an array of all registered plugins
    def self.all
      registered_plugins.values.sort
    end

    # Finds a plugin by its id
    # Returns a PluginNotFound exception if the plugin doesn't exist
    def self.find(id)
      registered_plugins[id.to_sym] || raise(PluginNotFound)
    end

    # Clears the registered plugins hash
    # It doesn't unload installed plugins
    def self.clear
      @registered_plugins = {}
    end

    # Removes a plugin from the registered plugins
    # It doesn't unload the plugin
    def self.unregister(id)
      @registered_plugins.delete(id)
    end

    # Checks if a plugin is installed
    #
    # @param [String] id name of the plugin
    def self.installed?(id)
      registered_plugins[id.to_sym].present?
    end

    def initialize(id)
      @id = id.to_sym
    end

    def public_directory
      File.join(self.class.public_directory, id.to_s)
    end

    def to_param
      id
    end

    # Returns the absolute path to the plugin assets directory
    def assets_directory
      path.assets_dir
    end

    def <=>(plugin)
      self.id.to_s <=> plugin.id.to_s
    end

    # Sets a requirement on Redmine version
    # Raises a PluginRequirementError exception if the requirement is not met
    #
    # Examples
    #   # Requires Redmine 0.7.3 or higher
    #   requires_redmine :version_or_higher => '0.7.3'
    #   requires_redmine '0.7.3'
    #
    #   # Requires Redmine 0.7.x or higher
    #   requires_redmine '0.7'
    #
    #   # Requires a specific Redmine version
    #   requires_redmine :version => '0.7.3'              # 0.7.3 only
    #   requires_redmine :version => '0.7'                # 0.7.x
    #   requires_redmine :version => ['0.7.3', '0.8.0']   # 0.7.3 or 0.8.0
    #
    #   # Requires a Redmine version within a range
    #   requires_redmine :version => '0.7.3'..'0.9.1'     # >= 0.7.3 and <= 0.9.1
    #   requires_redmine :version => '0.7'..'0.9'         # >= 0.7.x and <= 0.9.x
    def requires_redmine(arg)
      arg = {:version_or_higher => arg} unless arg.is_a?(Hash)
      arg.assert_valid_keys(:version, :version_or_higher)

      current = Redmine::VERSION.to_a
      arg.each do |k, req|
        case k
        when :version_or_higher
          unless req.is_a?(String)
            raise ArgumentError.new(":version_or_higher accepts a version string only")
          end

          unless compare_versions(req, current) <= 0
            raise PluginRequirementError.new(
              "#{id} plugin requires Redmine #{req} or higher " \
              "but current is #{current.join('.')}"
            )
          end
        when :version
          req = [req] if req.is_a?(String)
          if req.is_a?(Array)
            unless req.detect {|ver| compare_versions(ver, current) == 0}
              raise PluginRequirementError.new(
                "#{id} plugin requires one the following Redmine versions: " \
                "#{req.join(', ')} but current is #{current.join('.')}"
              )
            end
          elsif req.is_a?(Range)
            unless compare_versions(req.first, current) <= 0 && compare_versions(req.last, current) >= 0
              raise PluginRequirementError.new(
                "#{id} plugin requires a Redmine version between #{req.first} " \
                "and #{req.last} but current is #{current.join('.')}"
              )
            end
          else
            raise ArgumentError.new(":version option accepts a version string, an array or a range of versions")
          end
        end
      end
      true
    end

    def compare_versions(requirement, current)
      requirement = requirement.split('.').collect(&:to_i)
      requirement <=> current.slice(0, requirement.size)
    end
    private :compare_versions

    # Sets a requirement on a Redmine plugin version
    # Raises a PluginRequirementError exception if the requirement is not met
    #
    # Examples
    #   # Requires a plugin named :foo version 0.7.3 or higher
    #   requires_redmine_plugin :foo, :version_or_higher => '0.7.3'
    #   requires_redmine_plugin :foo, '0.7.3'
    #
    #   # Requires a specific version of a Redmine plugin
    #   requires_redmine_plugin :foo, :version => '0.7.3'              # 0.7.3 only
    #   requires_redmine_plugin :foo, :version => ['0.7.3', '0.8.0']   # 0.7.3 or 0.8.0
    def requires_redmine_plugin(plugin_name, arg)
      arg = {:version_or_higher => arg} unless arg.is_a?(Hash)
      arg.assert_valid_keys(:version, :version_or_higher)

      begin
        plugin = Plugin.find(plugin_name)
      rescue PluginNotFound
        raise PluginRequirementError.new("#{id} plugin requires the #{plugin_name} plugin")
      end
      current = plugin.version.split('.').collect(&:to_i)

      arg.each do |k, v|
        v = [] << v unless v.is_a?(Array)
        versions = v.collect {|s| s.split('.').collect(&:to_i)}
        case k
        when :version_or_higher
          unless versions.size == 1
            raise ArgumentError.new("wrong number of versions (#{versions.size} for 1)")
          end

          unless (current <=> versions.first) >= 0
            raise PluginRequirementError.new(
              "#{id} plugin requires the #{plugin_name} plugin #{v} or higher " \
              "but current is #{current.join('.')}"
            )
          end
        when :version
          unless versions.include?(current.slice(0, 3))
            raise PluginRequirementError.new(
              "#{id} plugin requires one the following versions of #{plugin_name}: " \
              "#{v.join(', ')} but current is #{current.join('.')}"
            )
          end
        end
      end
      true
    end

    # Adds an item to the given +menu+.
    # The +id+ parameter (equals to the project id) is automatically added to the url.
    #   menu :project_menu, :plugin_example, { :controller => 'example', :action => 'say_hello' }, :caption => 'Sample'
    #
    # +name+ parameter can be: :top_menu, :account_menu, :application_menu or :project_menu
    #
    def menu(menu, item, url, options={})
      Redmine::MenuManager.map(menu).push(item, url, options)
    end
    alias :add_menu_item :menu

    # Removes +item+ from the given +menu+.
    def delete_menu_item(menu, item)
      Redmine::MenuManager.map(menu).delete(item)
    end

    # Defines a permission called +name+ for the given +actions+.
    #
    # The +actions+ argument is a hash with controllers as keys and actions as values (a single value or an array):
    #   permission :destroy_contacts, { :contacts => :destroy }
    #   permission :view_contacts, { :contacts => [:index, :show] }
    #
    # The +options+ argument is a hash that accept the following keys:
    # * :public => the permission is public if set to true (implicitly given to any user)
    # * :require => can be set to one of the following values to restrict users the permission can be given to: :loggedin, :member
    # * :read => set it to true so that the permission is still granted on closed projects
    #
    # Examples
    #   # A permission that is implicitly given to any user
    #   # This permission won't appear on the Roles & Permissions setup screen
    #   permission :say_hello, { :example => :say_hello }, :public => true, :read => true
    #
    #   # A permission that can be given to any user
    #   permission :say_hello, { :example => :say_hello }
    #
    #   # A permission that can be given to registered users only
    #   permission :say_hello, { :example => :say_hello }, :require => :loggedin
    #
    #   # A permission that can be given to project members only
    #   permission :say_hello, { :example => :say_hello }, :require => :member
    def permission(name, actions, options = {})
      if @project_module
        Redmine::AccessControl.map do |map|
          map.project_module(@project_module) do |map|
            map.permission(name, actions, options)
          end
        end
      else
        Redmine::AccessControl.map {|map| map.permission(name, actions, options)}
      end
    end

    # Defines a project module, that can be enabled/disabled for each project.
    # Permissions defined inside +block+ will be bind to the module.
    #
    #   project_module :things do
    #     permission :view_contacts, { :contacts => [:list, :show] }, :public => true
    #     permission :destroy_contacts, { :contacts => :destroy }
    #   end
    def project_module(name, &block)
      @project_module = name
      self.instance_eval(&block)
      @project_module = nil
    end

    # Registers an activity provider.
    #
    # Options:
    # * <tt>:class_name</tt> - one or more model(s) that provide these events (inferred from event_type by default)
    # * <tt>:default</tt> - setting this option to false will make the events not displayed by default
    #
    # A model can provide several activity event types.
    #
    # Examples:
    #   register :news
    #   register :scrums, :class_name => 'Meeting'
    #   register :issues, :class_name => ['Issue', 'Journal']
    #
    # Retrieving events:
    # Associated model(s) must implement the find_events class method.
    # ActiveRecord models can use acts_as_activity_provider as a way to implement this class method.
    #
    # The following call should return all the scrum events visible by current user that occurred in the 5 last days:
    #   Meeting.find_events('scrums', User.current, 5.days.ago, Date.today)
    #   Meeting.find_events('scrums', User.current, 5.days.ago, Date.today, :project => foo) # events for project foo only
    #
    # Note that :view_scrums permission is required to view these events in the activity view.
    def activity_provider(*args)
      Redmine::Activity.register(*args)
    end

    # Registers a wiki formatter.
    #
    # Parameters:
    # * +name+ - formatter name
    # * +formatter+ - formatter class, which should have an instance method +to_html+
    # * +helper+ - helper module, which will be included by wiki pages (optional)
    # * +html_parser+ class reponsible for converting HTML to wiki text (optional)
    # * +options+ - a Hash of options (optional)
    #   * :label - label for the formatter displayed in application settings
    #
    # Examples:
    #   wiki_format_provider(:custom_formatter, CustomFormatter, :label => "My custom formatter")
    #
    def wiki_format_provider(name, *args)
      Redmine::WikiFormatting.register(name, *args)
    end

    # Register plugin models that use acts_as_attachable.
    #
    # Example:
    #   attachment_object_type SomeAttachableModel
    #
    # This is necessary for the core attachments controller routes and attachments/_form to work.
    def attachment_object_type(*args)
      args.each do |klass|
        Redmine::Acts::Attachable::ObjectTypeConstraint.register_object_type(klass.name.underscore.pluralize)
      end
    end

    # Returns +true+ if the plugin can be configured.
    def configurable?
      settings && settings.is_a?(Hash) && !settings[:partial].blank?
    end

    # The directory containing this plugin's migrations (<tt>plugin/db/migrate</tt>)
    def migration_directory
      File.join(directory, 'db', 'migrate')
    end

    # Returns the version number of the latest migration for this plugin. Returns
    # nil if this plugin has no migrations.
    def latest_migration
      migrations.last
    end

    # Returns the version numbers of all migrations for this plugin.
    def migrations
      migrations = Dir[migration_directory+"/*.rb"]
      migrations.map {|p| File.basename(p).match(/0*(\d+)\_/)[1].to_i}.sort
    end

    # Migrate this plugin to the given version
    def migrate(version = nil)
      Redmine::Plugin::Migrator.migrate_plugin(self, version)
    end

    # Migrates all plugins or a single plugin to a given version
    # Exemples:
    #   Plugin.migrate
    #   Plugin.migrate('sample_plugin')
    #   Plugin.migrate('sample_plugin', 1)
    #
    def self.migrate(name=nil, version=nil)
      if name.present?
        find(name).migrate(version)
      else
        all.each do |plugin|
          plugin.migrate
        end
      end
    end

    class MigrationContext < ActiveRecord::MigrationContext
      def up(target_version = nil)
        selected_migrations =
          if block_given?
            migrations.select {|m| yield m}
          else
            migrations
          end
        Migrator.new(:up, selected_migrations, schema_migration, target_version).migrate
      end

      def down(target_version = nil)
        selected_migrations =
          if block_given?
            migrations.select {|m| yield m}
          else
            migrations
          end
        Migrator.new(:down, selected_migrations, schema_migration, target_version).migrate
      end

      def run(direction, target_version)
        Migrator.new(direction, migrations, schema_migration, target_version).run
      end

      def open
        Migrator.new(:up, migrations, schema_migration)
      end
    end

    class Migrator < ActiveRecord::Migrator
      # We need to be able to set the 'current' plugin being migrated.
      cattr_accessor :current_plugin

      class << self
        # Runs the migrations from a plugin, up (or down) to the version given
        def migrate_plugin(plugin, version)
          self.current_plugin = plugin
          return if current_version(plugin) == version

          MigrationContext.new(plugin.migration_directory, ::ActiveRecord::Base.connection.schema_migration).migrate(version)
        end

        def get_all_versions(plugin = current_plugin)
          # Delete migrations that don't match .. to_i will work because the number comes first
          @all_versions ||= {}
          @all_versions[plugin.id.to_s] ||= begin
            sm_table = ::ActiveRecord::SchemaMigration.table_name
            migration_versions  = ActiveRecord::Base.connection.select_values("SELECT version FROM #{sm_table}")
            versions_by_plugins = migration_versions.group_by {|version| version.match(/-(.*)$/).try(:[], 1)}
            @all_versions       = versions_by_plugins.transform_values! {|versions| versions.map!(&:to_i).sort!}
            @all_versions[plugin.id.to_s] || []
          end
        end

        def current_version(plugin = current_plugin)
          get_all_versions(plugin).last || 0
        end
      end

      def load_migrated
        @migrated_versions = Set.new(self.class.get_all_versions(current_plugin))
      end

      def record_version_state_after_migrating(version)
        super(version.to_s + "-" + current_plugin.id.to_s)
      end
    end
  end
end
