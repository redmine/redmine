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
    module SyntaxHighlight
      def process(node, text, lang)
        # original language for extension development
        node['data-language'] = lang unless node['data-language']

        if Redmine::SyntaxHighlighting.language_supported?(lang)
          html = Redmine::SyntaxHighlighting.highlight_by_language(text, lang)
          return if html.nil?

          node.inner_html = html
          node['class'] = "#{lang} syntaxhl"
        else
          # unsupported language, remove the class attribute
          node.remove_attribute('class')
        end

        # Rouge has no mermaid lexer, so the branch above leaves the block as plain text.
        # This attribute is what the mermaid Stimulus controller looks for to replace the block
        # with a rendered diagram. Only block-level code is rendered; an inline <code class="mermaid">
        # written in Textile is left as is.
        # The attribute is added even when Mermaid.js is not installed: formatted text may be cached
        # (see Setting.cache_formatted_text), and the controller does nothing unless Mermaid.js is available.
        if lang.to_s.downcase == 'mermaid' && node.parent&.name == 'pre'
          node['data-controller'] = 'mermaid'
        end
      end
    end
  end
end
