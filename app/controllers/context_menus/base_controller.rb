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

module ContextMenus
  class BaseController < ApplicationController
    layout false
    helper :context_menus
    helper_method :url_for

    def url_for(options = nil)
      if options.is_a?(Hash) && options[:controller].present?
        controller_name = options[:controller].to_s
        unless controller_name.start_with?('/')
          options = options.dup
          options[:controller] = "/#{controller_name}"
        end
      end
      super
    end

    private

    def render_context_menu(template_name)
      @back = back_url
      render :template => "context_menus/#{template_name}"
    end
  end
end
