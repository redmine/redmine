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
  module MenuManager
    # @private
    class MenuError < StandardError
    end

    module MenuController
      def self.included(base)
        base.class_attribute :main_menu
        base.main_menu = true

        base.extend(ClassMethods)
      end

      module ClassMethods
        @@menu_items = Hash.new {|hash, key| hash[key] = {:default => key, :actions => {}}}
        mattr_accessor :menu_items

        # Set the menu item name for a controller or specific actions
        # Examples:
        #   * menu_item :tickets # => sets the menu name to :tickets for the whole controller
        #   * menu_item :tickets, :only => :list # => sets the menu name to :tickets for the 'list' action only
        #   * menu_item :tickets, :only => [:list, :show] # => sets the menu name to :tickets for 2 actions only
        #
        # The default menu item name for a controller is controller_name by default
        # Eg. the default menu item name for ProjectsController is :projects
        def menu_item(id, options = {})
          if actions = options[:only]
            actions = [] << actions unless actions.is_a?(Array)
            actions.each {|a| menu_items[controller_name.to_sym][:actions][a.to_sym] = id}
          else
            menu_items[controller_name.to_sym][:default] = id
          end
        end
      end

      def menu_items
        self.class.menu_items
      end

      def current_menu(project)
        if project && !project.new_record?
          :project_menu
        elsif self.class.main_menu
          :application_menu
        end
      end

      # Returns the menu item name according to the current action
      def current_menu_item
        @current_menu_item ||= menu_items[controller_name.to_sym][:actions][action_name.to_sym] ||
                                 menu_items[controller_name.to_sym][:default]
      end

      # Redirects user to the menu item
      # Returns false if user is not authorized
      def redirect_to_menu_item(name)
        redirect_to_project_menu_item(nil, name)
      end

      # Redirects user to the menu item of the given project
      # Returns false if user is not authorized
      def redirect_to_project_menu_item(project, name)
        menu = project.nil? ? :application_menu : :project_menu
        item = Redmine::MenuManager.items(menu).detect {|i| i.name.to_s == name.to_s}
        if item && item.allowed?(User.current, project)
          url = item.url
          url = {item.param => project}.merge(url) if project
          redirect_to url
          return true
        end
        false
      end
    end

    module MenuHelper
      # Returns the current menu item name
      def current_menu_item
        controller.current_menu_item
      end

      # Renders the application main menu
      def render_main_menu(project)
        if menu_name = controller.current_menu(project)
          render_menu(menu_name, project)
        end
      end

      def display_main_menu?(project)
        menu_name = controller.current_menu(project)
        menu_name.present? && Redmine::MenuManager.items(menu_name).children.present?
      end

      def render_menu(menu, project=nil)
        links = []
        menu_items_for(menu, project) do |node|
          links << render_menu_node(node, project)
        end
        links.empty? ? nil : content_tag('ul', links.join.html_safe)
      end

      def render_menu_node(node, project=nil)
        if node.children.present? || !node.child_menus.nil?
          return render_menu_node_with_children(node, project)
        else
          caption, url, selected = extract_node_details(node, project)
          return content_tag('li',
                             render_single_menu_node(node, caption, url, selected))
        end
      end

      def render_menu_node_with_children(node, project=nil)
        caption, url, selected = extract_node_details(node, project)

        html = [].tap do |html|
          html << '<li>'
          # Parent
          html << render_single_menu_node(node, caption, url, selected)

          # Standard children
          standard_children_list = "".html_safe.tap do |child_html|
            node.children.each do |child|
              child_html << render_menu_node(child, project) if allowed_node?(child, User.current, project)
            end
          end

          html << content_tag(:ul, standard_children_list, :class => 'menu-children') unless standard_children_list.empty?

          # Unattached children
          unattached_children_list = render_unattached_children_menu(node, project)
          html << content_tag(:ul, unattached_children_list, :class => 'menu-children unattached') unless unattached_children_list.blank?

          html << '</li>'
        end
        return html.join("\n").html_safe
      end

      # Returns a list of unattached children menu items
      def render_unattached_children_menu(node, project)
        return nil unless node.child_menus

        "".html_safe.tap do |child_html|
          unattached_children = node.child_menus.call(project)
          # Tree nodes support #each so we need to do object detection
          if unattached_children.is_a? Array
            unattached_children.each do |child|
              child_html << content_tag(:li, render_unattached_menu_item(child, project)) if allowed_node?(child, User.current, project)
            end
          else
            raise MenuError, ":child_menus must be an array of MenuItems"
          end
        end
      end

      def render_single_menu_node(item, caption, url, selected)
        options = item.html_options(:selected => selected)

        # virtual nodes are only there for their children to be displayed in the menu
        # and should not do anything on click, except if otherwise defined elsewhere
        if url.blank?
          url = '#'
          options.reverse_merge!(:onclick => 'return false;')
        end

        label = if item.icon.present?
                  sprite_icon(item.icon, h(caption), plugin: item.plugin)
                else
                  h(caption)
                end

        link_to(label, use_absolute_controller(url), options)
      end

      def render_unattached_menu_item(menu_item, project)
        raise MenuError, ":child_menus must be an array of MenuItems" unless menu_item.is_a? MenuItem

        if menu_item.allowed?(User.current, project)
          link_to(menu_item.caption, use_absolute_controller(menu_item.url), menu_item.html_options)
        end
      end

      def menu_items_for(menu, project=nil)
        items = []
        Redmine::MenuManager.items(menu).root.children.each do |node|
          if node.allowed?(User.current, project)
            if block_given?
              yield node
            else
              items << node  # TODO: not used?
            end
          end
        end
        return block_given? ? nil : items
      end

      def extract_node_details(node, project=nil)
        item = node
        url =
          case item.url
          when Hash
            project.nil? ? item.url : {item.param => project}.merge(item.url)
          when Symbol
            if project
              send(item.url, project)
            else
              send(item.url)
            end
          else
            item.url
          end
        caption = item.caption(project)
        return [caption, url, (current_menu_item == item.name)]
      end

      # See MenuItem#allowed?
      def allowed_node?(node, user, project)
        unless node.is_a? MenuItem
          raise MenuError, ":child_menus must be an array of MenuItems"
        end

        node.allowed?(user, project)
      end

      # Prevent hash type URLs (e.g. {controller: 'foo', action: 'bar}) from being namespaced
      # when menus are rendered from views in namespaced controllers in plugins or engines
      def use_absolute_controller(url)
        if url.is_a?(Hash) && url[:controller].present? && !url[:controller].start_with?('/')
          url[:controller] = "/#{url[:controller]}"
        end
        url
      end
    end

    class << self
      def map(menu_name)
        @items ||= {}
        mapper = Mapper.new(menu_name.to_sym, @items)
        if block_given?
          yield mapper
        else
          mapper
        end
      end

      def items(menu_name)
        @items[menu_name.to_sym] || MenuNode.new(:root, {})
      end
    end

    class Mapper
      attr_reader :menu, :menu_items

      def initialize(menu, items)
        items[menu] ||= MenuNode.new(:root, {})
        @menu = menu
        @menu_items = items[menu]
      end

      # Adds an item at the end of the menu. Available options:
      # * param: the parameter name that is used for the project id (default is :id)
      # * if: a Proc that is called before rendering the item, the item is displayed only if it returns true
      # * caption that can be:
      #   * a localized string Symbol
      #   * a String
      #   * a Proc that can take the project as argument
      # * before, after: specify where the menu item should be inserted (eg. :after => :activity)
      # * parent: menu item will be added as a child of another named menu (eg. :parent => :issues)
      # * children: a Proc that is called before rendering the item. The Proc should return an array of MenuItems, which will be added as children to this item.
      #   eg. :children => Proc.new {|project| [Redmine::MenuManager::MenuItem.new(...)] }
      # * last: menu item will stay at the end (eg. :last => true)
      # * html_options: a hash of html options that are passed to link_to
      def push(name, url, options={})
        options = options.dup

        if options[:parent]
          subtree = self.find(options[:parent])
          target_root = subtree || @menu_items.root

        else
          target_root = @menu_items.root
        end

        target_root.children.reject! {|item| item.name == name}

        # menu item position
        if first = options.delete(:first)
          target_root.prepend(MenuItem.new(name, url, options))
        elsif before = options.delete(:before)

          if exists?(before)
            target_root.add_at(MenuItem.new(name, url, options), position_of(before))
          else
            target_root.add(MenuItem.new(name, url, options))
          end

        elsif after = options.delete(:after)

          if exists?(after)
            target_root.add_at(MenuItem.new(name, url, options), position_of(after) + 1)
          else
            target_root.add(MenuItem.new(name, url, options))
          end

        elsif options[:last] # don't delete, needs to be stored
          target_root.add_last(MenuItem.new(name, url, options))
        else
          target_root.add(MenuItem.new(name, url, options))
        end
      end

      # Removes a menu item
      def delete(name)
        if found = self.find(name)
          @menu_items.remove!(found)
        end
      end

      # Checks if a menu item exists
      def exists?(name)
        @menu_items.any? {|node| node.name == name}
      end

      def find(name)
        @menu_items.find {|node| node.name == name}
      end

      def position_of(name)
        @menu_items.each do |node|
          if node.name == name
            return node.position
          end
        end
      end
    end

    class MenuNode
      include Enumerable
      attr_accessor :parent
      attr_reader :last_items_count, :name

      def initialize(name, content = nil)
        @name = name
        @children = []
        @last_items_count = 0
      end

      def children
        if block_given?
          @children.each {|child| yield child}
        else
          @children
        end
      end

      # Returns the number of descendants + 1
      def size
        @children.inject(1) {|sum, node| sum + node.size}
      end

      def each(...)
        yield self
        children {|child| child.each(...)}
      end

      # Adds a child at first position
      def prepend(child)
        add_at(child, 0)
      end

      # Adds a child at given position
      def add_at(child, position)
        @children.insert(position, child)
        child.parent = self
        child
      end

      # Adds a child as last child
      def add_last(child)
        add_at(child, -1)
        @last_items_count += 1
        child
      end

      # Adds a child
      def add(child)
        position = @children.size - @last_items_count
        add_at(child, position)
      end
      alias :<< :add

      # Removes a child
      def remove!(child)
        @children.delete(child)
        @last_items_count -= +1 if child && child.last
        child.parent = nil
        child
      end

      # Returns the position for this node in it's parent
      def position
        self.parent.children.index(self)
      end

      # Returns the root for this node
      def root
        root = self
        root = root.parent while root.parent
        root
      end
    end

    class MenuItem < MenuNode
      include Redmine::I18n
      attr_reader :name, :url, :param, :condition, :parent,
                  :child_menus, :last, :permission, :icon, :plugin

      def initialize(name, url, options={})
        if options[:if] && !options[:if].respond_to?(:call)
          raise ArgumentError, "Invalid option :if for menu item '#{name}'"
        end
        if options[:html] && !options[:html].is_a?(Hash)
          raise ArgumentError, "Invalid option :html for menu item '#{name}'"
        end
        if options[:parent] == name.to_sym
          raise ArgumentError, "Cannot set the :parent to be the same as this item"
        end
        if options[:children] && !options[:children].respond_to?(:call)
          raise ArgumentError, "Invalid option :children for menu item '#{name}'"
        end

        @name = name
        @url = url
        @condition = options[:if]
        @permission = options[:permission]
        @permission ||= false if options.key?(:permission)
        @param = options[:param] || :id
        @caption = options[:caption]
        @icon = options[:icon]
        @html_options = options[:html] || {}
        # Adds a unique class to each menu item based on its name
        @html_options[:class] = [@html_options[:class], @name.to_s.dasherize].compact.join(' ')
        @parent = options[:parent]
        @child_menus = options[:children]
        @last = options[:last] || false
        @plugin = options[:plugin]
        super(@name.to_sym)
      end

      def caption(project=nil)
        if @caption.is_a?(Proc)
          c = @caption.call(project).to_s
          c = @name.to_s.humanize if c.blank?
          c
        else
          if @caption.nil?
            l_or_humanize(name, :prefix => 'label_')
          else
            @caption.is_a?(Symbol) ? l(@caption) : @caption
          end
        end
      end

      def html_options(options={})
        if options[:selected]
          o = @html_options.dup
          o[:class] += ' selected'
          o
        else
          @html_options
        end
      end

      # Checks if a user is allowed to access the menu item by:
      #
      # * Checking the permission or the url target (project only)
      # * Checking the conditions of the item
      def allowed?(user, project)
        if url.blank?
          # this is a virtual node that is only there for its children to be diplayed in the menu
          # it is considered an allowed node if at least one of the children is allowed
          all_children = children
          all_children += child_menus.call(project) if child_menus
          unless all_children.detect{|child| child.allowed?(user, project)}
            return false
          end
        elsif user && project
          if permission
            unless user.allowed_to?(permission, project)
              return false
            end
          elsif permission.nil? && url.is_a?(Hash)
            unless user.allowed_to?(url, project)
              return false
            end
          end
        end
        if condition && !condition.call(project)
          # Condition that doesn't pass
          return false
        end

        return true
      end
    end
  end
end
