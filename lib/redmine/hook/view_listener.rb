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
  module Hook
    # Listener class used for views hooks.
    # Listeners that inherit this class will include various helpers by default.
    class ViewListener < Listener
      include ERB::Util
      include ActionView::Helpers::TagHelper
      include ActionView::Helpers::FormHelper
      include ActionView::Helpers::FormTagHelper
      include ActionView::Helpers::FormOptionsHelper
      include ActionView::Helpers::JavaScriptHelper
      include ActionView::Helpers::NumberHelper
      include ActionView::Helpers::UrlHelper
      include ActionView::Helpers::AssetTagHelper
      include ActionView::Helpers::TextHelper
      include Rails.application.routes.url_helpers
      include ApplicationHelper
      include Propshaft::Helper

      # Default to creating links using only the path.  Subclasses can
      # change this default as needed
      def self.default_url_options
        {:only_path => true, :script_name => Redmine::Utils.relative_url_root}
      end

      # Helper method to directly render using the context,
      # render_options must be valid #render options.
      #
      #   class MyHook < Redmine::Hook::ViewListener
      #     render_on :view_issues_show_details_bottom, :partial => "show_more_data"
      #   end
      #
      #   class MultipleHook < Redmine::Hook::ViewListener
      #     render_on :view_issues_show_details_bottom,
      #       {:partial => "show_more_data"},
      #       {:partial => "show_even_more_data"}
      #   end
      #
      def self.render_on(hook, *render_options)
        define_method hook do |context|
          render_options.map do |options|
            if context[:hook_caller].respond_to?(:render)
              context[:hook_caller].send(:render, {:locals => context}.merge(options))
            elsif context[:controller].is_a?(ActionController::Base)
              context[:controller].send(:render_to_string, {:locals => context}.merge(options))
            else
              raise "Cannot render #{self.name} hook from #{context[:hook_caller].class.name}"
            end
          end
        end
      end

      def controller
        nil
      end

      def config
        ActionController::Base.config
      end
    end
  end
end
