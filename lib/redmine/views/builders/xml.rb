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

require 'builder'

module Redmine
  module Views
    module Builders
      class Xml < ::Builder::XmlMarkup
        def initialize(request, response)
          super()
          instruct!
        end

        def output
          target!
        end

        # Overrides Builder::XmlBase#tag! to format timestamps in ISO 8601
        def tag!(sym, *args, &block)
          if args.size == 1 && args.first.is_a?(::Time)
            tag! sym, args.first.xmlschema, &block
          else
            super
          end
        end

        def array(name, options={}, &block)
          __send__ name, (options || {}).merge(:type => 'array'), &block
        end
      end
    end
  end
end
