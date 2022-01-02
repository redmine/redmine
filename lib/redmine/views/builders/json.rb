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

require 'redmine/views/builders/structure'

module Redmine
  module Views
    module Builders
      class Json < Structure
        attr_accessor :jsonp

        def initialize(request, response)
          super
          callback = request.params[:callback] || request.params[:jsonp]
          if callback && Setting.jsonp_enabled?
            self.jsonp = callback.to_s.gsub(/[^a-zA-Z0-9_.]/, '')
          end
        end

        def output
          json = @struct.first.to_json
          if jsonp.present?
            json = "#{jsonp}(#{json})"
            @response.content_type = 'application/javascript'
          end
          json
        end
      end
    end
  end
end
