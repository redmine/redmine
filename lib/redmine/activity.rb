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
  module Activity
    mattr_accessor :available_event_types, :default_event_types, :plugins_event_types, :providers

    @@available_event_types = []
    @@default_event_types = []
    @@plugins_event_types = {}
    @@providers = Hash.new {|h, k| h[k]=[]}

    class << self
      def map(&)
        yield self
      end

      # Registers an activity provider
      def register(event_type, options={})
        options.assert_valid_keys(:class_name, :default, :plugin)

        event_type = event_type.to_s
        providers = options[:class_name] || event_type.classify
        providers = ([] << providers) unless providers.is_a?(Array)

        @@available_event_types << event_type unless @@available_event_types.include?(event_type)
        @@default_event_types << event_type unless options[:default] == false
        @@plugins_event_types = { event_type => options[:plugin].to_s } unless options[:plugin].nil?
        @@providers[event_type] += providers
      end

      def delete(event_type)
        @@available_event_types.delete event_type
        @@default_event_types.delete event_type
        @@plugins_event_types.delete(event_type)
        @@providers.delete(event_type)
      end

      def plugin_name(event_type)
        @@plugins_event_types[event_type]
      end
    end
  end
end
