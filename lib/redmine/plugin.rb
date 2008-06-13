# redMine - project management software
# Copyright (C) 2006-2007  Jean-Philippe Lang
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

module Redmine #:nodoc:

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
  class Plugin
    @registered_plugins = {}
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
    def_field :name, :description, :author, :version, :settings
  
    # Plugin constructor
    def self.register(name, &block)
      p = new
      p.instance_eval(&block)
      Plugin.registered_plugins[name] = p
    end

    # Adds an item to the given +menu+.
    # The +id+ parameter (equals to the project id) is automatically added to the url.
    #   menu :project_menu, :plugin_example, { :controller => 'example', :action => 'say_hello' }, :caption => 'Sample'
    #   
    # +name+ parameter can be: :top_menu, :account_menu, :application_menu or :project_menu
    # 
    def menu(name, item, url, options={})
      Redmine::MenuManager.map(name) {|menu| menu.push item, url, options}
    end

    # Defines a permission called +name+ for the given +actions+.
    # 
    # The +actions+ argument is a hash with controllers as keys and actions as values (a single value or an array):
    #   permission :destroy_contacts, { :contacts => :destroy }
    #   permission :view_contacts, { :contacts => [:index, :show] }
    # 
    # The +options+ argument can be used to make the permission public (implicitly given to any user)
    # or to restrict users the permission can be given to.
    # 
    # Examples
    #   # A permission that is implicitly given to any user
    #   # This permission won't appear on the Roles & Permissions setup screen
    #   permission :say_hello, { :example => :say_hello }, :public => true
    # 
    #   # A permission that can be given to any user
    #   permission :say_hello, { :example => :say_hello }
    #   
    #   # A permission that can be given to registered users only
    #   permission :say_hello, { :example => :say_hello }, :require => loggedin
    #   
    #   # A permission that can be given to project members only
    #   permission :say_hello, { :example => :say_hello }, :require => member
    def permission(name, actions, options = {})
      if @project_module
        Redmine::AccessControl.map {|map| map.project_module(@project_module) {|map|map.permission(name, actions, options)}}
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
    
    # Registers a +method+ to be called when Redmine runs a hook called
    # +hook_name+
    #
    #   # Run puts whenever the issue_show hook is called
    #   add_hook :issue_show, Proc.new { puts 'Hello' }
    #
    #   # Call the class method +my_method+ passing in all the context
    #   add_hook :issue_show, Proc.new {|context| MyPlugin.my_method(context)}
    def add_hook(hook_name, method)
      Redmine::Plugin::Hook::Manager.add_listener(hook_name, method)
    end

    # Returns +true+ if the plugin can be configured.
    def configurable?
      settings && settings.is_a?(Hash) && !settings[:partial].blank?
    end
    
    # Hook is used to allow plugins to hook into Redmine at specific sections
    # to change it's behavior.  See +Redmine::Plugin.add_hook+ for details.
    class Hook
      class Manager
        # Hooks and the procs added
        @@hooks = {
          :issue_show => [],
          :issue_edit => [],
          :issue_bulk_edit => [],
          :issue_bulk_edit_save => [],
          :issue_update => [],
          :project_member_list_header => [],
          :project_member_list_column_three => [],
          :issues_helper_show_details => []
        }
        
        cattr_reader :hooks
      
        class << self
        
          def valid_hook?(hook_name)
            return @@hooks.has_key?(hook_name)
          end

          # Add +method+ to +hook_name+
          def add_listener(hook_name, method)
            if valid_hook?(hook_name)
              @@hooks[hook_name.to_sym] << method
              puts "Listener added for #{hook_name.to_s}"
            end
          end
        
          # Run all the hooks for +hook_name+ passing in +context+
          def call_hook(hook_name, context = { })
            response = ''
            @@hooks[hook_name.to_sym].each do |method|
              response += method.call(context)
            end
            response
          end
        
          # Are hooks registered for +hook_name+
          def hook_registered?(hook_name)
            return @@hooks[hook_name.to_sym].size > 0
          end
        end
      end

      # Base class for Redmin Plugin hooks.
      class Base
        
        # Class level access to Rails' helper methods.
        def self.help
          Helper.instance
        end
        
        # Includes several Helper methods to be used in the class
        class Helper # :nodoc:
          include Singleton
          include ERB::Util
          include ActionView::Helpers::TagHelper
          include ActionView::Helpers::FormHelper
          include ActionView::Helpers::FormTagHelper
          include ActionView::Helpers::FormOptionsHelper
          include ActionView::Helpers::JavaScriptHelper 
          include ActionView::Helpers::PrototypeHelper
          include ActionView::Helpers::NumberHelper
          include ActionView::Helpers::UrlHelper
          
          include ActionController::UrlWriter 
          
          def protect_against_forgery? # :nodoc:
            false
          end
          
        end
      end
    end
  end
end
