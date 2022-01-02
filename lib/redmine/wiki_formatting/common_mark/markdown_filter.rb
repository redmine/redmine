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
  module WikiFormatting
    module CommonMark
      # Converts Markdown to HTML using CommonMarker
      #
      # We do not use the stock HTML::Pipeline::MarkdownFilter because this
      # does not allow for straightforward configuration of render and parsing
      # options
      class MarkdownFilter < HTML::Pipeline::TextFilter
        def initialize(text, context = nil, result = nil)
          super text, context, result
          @text = @text.delete "\r"
        end

        def call
          doc = CommonMarker.render_doc(@text, parse_options, extensions)
          html = doc.to_html render_options, extensions
          html.rstrip!
          html
        end

        private

        def extensions
          context.fetch :commonmarker_extensions, []
        end

        def parse_options
          context.fetch :commonmarker_parse_options, :DEFAULT
        end

        def render_options
          context.fetch :commonmarker_render_options, :DEFAULT
        end
      end
    end
  end
end
