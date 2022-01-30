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

require 'redmine/views/builders/json'
require 'redmine/views/builders/xml'

module Redmine
  module Views
    module Builders
      class << self
        def for(format, request, response, &block)
          builder =
            case format
            when 'xml',  :xml  then Builders::Xml.new(request, response)
            when 'json', :json then Builders::Json.new(request, response)
            else
              Rails.logger.error "No builder for format #{format.inspect}"
              response.status = 406
              return "We couldn't handle your request, sorry. If you were trying to access the API, make sure to append .json or .xml to your request URL.\n"
            end
          if block_given?
            yield(builder)
          else
            builder
          end
        end
      end
    end
  end
end
