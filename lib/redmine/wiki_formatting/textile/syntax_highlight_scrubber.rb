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
  module WikiFormatting
    module Textile
      # Redmine Syntax highlighting for <pre><code class="foo">
      class SyntaxHighlightScrubber < Loofah::Scrubber
        include Redmine::WikiFormatting::SyntaxHighlight

        def scrub(node)
          return unless node.name == 'code'
          return unless lang = node['class'].presence

          text = node.inner_text
          if text.start_with?("\n")
            text = text.sub("\n", "")
          end

          process node, text, lang
        end
      end
    end
  end
end
