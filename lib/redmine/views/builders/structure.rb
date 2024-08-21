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
  module Views
    module Builders
      class Structure < BasicObject
        def initialize(request, response)
          @struct = [{}]
          @request = request
          @response = response
        end

        def array(tag, options={}, &)
          @struct << []
          yield(self)
          ret = @struct.pop
          @struct.last[tag] = ret
          @struct.last.merge!(options) if options
        end

        def encode_value(value)
          if value.is_a?(::Time)
            # Rails uses a global setting to format JSON times
            # Don't rely on it for the API as it could have been changed
            value.xmlschema(0)
          else
            value
          end
        end

        def method_missing(sym, *args, &block)
          if args.count > 0
            if args.first.is_a?(::Hash)
              if @struct.last.is_a?(::Array)
                @struct.last << args.first unless block
              else
                @struct.last[sym] = args.first
              end
            else
              value = encode_value(args.first)
              if @struct.last.is_a?(::Array)
                if args.size == 1 && !block
                  @struct.last << value
                else
                  @struct.last << (args.last || {}).merge(:value => value)
                end
              else
                @struct.last[sym] = value
              end
            end
          end
          if block
            @struct << (args.first.is_a?(::Hash) ? args.first : {})
            yield(self)
            ret = @struct.pop
            if @struct.last.is_a?(::Array)
              @struct.last << ret
            else
              if @struct.last.has_key?(sym) && @struct.last[sym].is_a?(::Hash)
                @struct.last[sym].merge! ret
              else
                @struct.last[sym] = ret
              end
            end
          end
        end

        def output
          raise "Need to implement #{self.class.name}#output"
        end
      end
    end
  end
end
