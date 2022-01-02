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
  module Hook
    @@listener_classes = []
    @@listeners = nil
    @@hook_listeners = {}

    class << self
      # Adds a listener class.
      # Automatically called when a class inherits from Redmine::Hook::Listener.
      def add_listener(klass)
        unless klass.included_modules.include?(Singleton)
          raise "Hooks must include Singleton module."
        end

        @@listener_classes << klass
        clear_listeners_instances
      end

      # Returns all the listener instances.
      def listeners
        @@listeners ||= @@listener_classes.collect {|listener| listener.instance}
      end

      # Returns the listener instances for the given hook.
      def hook_listeners(hook)
        @@hook_listeners[hook] ||= listeners.select {|listener| listener.respond_to?(hook)}
      end

      # Clears all the listeners.
      def clear_listeners
        @@listener_classes = []
        clear_listeners_instances
      end

      # Clears all the listeners instances.
      def clear_listeners_instances
        @@listeners = nil
        @@hook_listeners = {}
      end

      # Calls a hook.
      # Returns the listeners response.
      def call_hook(hook, context={})
        [].tap do |response|
          hls = hook_listeners(hook)
          if hls.any?
            hls.each {|listener| response << listener.send(hook, context)}
          end
        end
      end
    end

    # Helper module included in ApplicationHelper and ActionController so that
    # hooks can be called in views like this:
    #
    #   <%= call_hook(:some_hook) %>
    #   <%= call_hook(:another_hook, :foo => 'bar') %>
    #
    # Or in controllers like:
    #   call_hook(:some_hook)
    #   call_hook(:another_hook, :foo => 'bar')
    #
    # Hooks added to views will be concatenated into a string. Hooks added to
    # controllers will return an array of results.
    #
    # Several objects are automatically added to the call context:
    #
    # * project => current project
    # * request => Request instance
    # * controller => current Controller instance
    # * hook_caller => object that called the hook
    #
    module Helper
      def call_hook(hook, context={})
        if is_a?(ActionController::Base)
          default_context = {:controller => self, :project => @project, :request => request, :hook_caller => self}
          Redmine::Hook.call_hook(hook, default_context.merge(context))
        else
          default_context = {:project => @project, :hook_caller => self}
          default_context[:controller] = controller if respond_to?(:controller)
          default_context[:request] = request if respond_to?(:request)
          Redmine::Hook.call_hook(hook, default_context.merge(context)).join(' ').html_safe
        end
      end
    end
  end
end
