# Redmine - project management software
# Copyright (C) 2006-2017  Jean-Philippe Lang
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

require 'loofah/helpers'

module Redmine
  module WikiFormatting
    class HtmlParser

      class_attribute :tags
      self.tags = {
        'br' => {:post => "\n"},
        'style' => ''
      }

      def self.to_text(html)
        html = html.gsub(/[\n\r]/, '').squeeze(' ')
    
        doc = Loofah.document(html)
        doc.scrub!(WikiTags.new(tags))
        doc.scrub!(:newline_block_elements)
    
        Loofah::Helpers.remove_extraneous_whitespace(doc.text).strip
      end

      class WikiTags < ::Loofah::Scrubber
        def initialize(tags_to_text)
          @direction = :bottom_up
          @tags_to_text = tags_to_text || {}
        end
    
        def scrub(node)
          formatting = @tags_to_text[node.name]
          case formatting
          when Hash
            node.add_next_sibling Nokogiri::XML::Text.new("#{formatting[:pre]}#{node.content}#{formatting[:post]}", node.document)
            node.remove
          when String
            node.add_next_sibling Nokogiri::XML::Text.new(formatting, node.document)
            node.remove
          else
            CONTINUE
          end
        end
      end
    end
  end
end
