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
      # sanitizes rendered HTML using the Sanitize gem
      class SanitizationFilter < HTML::Pipeline::SanitizationFilter
        include Redmine::Helpers::URL
        RELAXED_PROTOCOL_ATTRS = {
          "a" => %w(href).freeze,
        }.freeze

        ALLOWED_CSS_PROPERTIES = %w[
          color background-color
          width
          height
          padding padding-left padding-right padding-top padding-bottom
          margin margin-left margin-right margin-top margin-bottom
          border border-left border-right border-top border-bottom border-radius border-style border-collapse border-spacing
          font font-style font-variant font-weight font-stretch font-size line-height font-family
          text-align
          float
        ].freeze

        def allowlist
          @allowlist ||= customize_allowlist(super.deep_dup)
        end

        private

        # customizes the allowlist defined in
        # https://github.com/jch/html-pipeline/blob/master/lib/html/pipeline/sanitization_filter.rb
        def customize_allowlist(allowlist)
          # Disallow `name` attribute globally, allow on `a`
          allowlist[:attributes][:all].delete("name")
          allowlist[:attributes]["a"].push("name")

          allowlist[:attributes][:all].push("style")
          allowlist[:css] = { properties: ALLOWED_CSS_PROPERTIES }

          # allow class on code tags (this holds the language info from fenced
          # code bocks and has the format language-foo)
          allowlist[:attributes]["code"] = %w(class)
          allowlist[:transformers].push lambda{|env|
            node = env[:node]
            return unless node.name == "code"
            return unless node.has_attribute?("class")

            unless /\Alanguage-(\S+)\z/.match?(node["class"])
              node.remove_attribute("class")
            end
          }

          # Allow table cell alignment by style attribute
          #
          # Only necessary if we used the TABLE_PREFER_STYLE_ATTRIBUTES
          # commonmarker option (which we do not, currently).
          # By default, the align attribute is used (which is allowed on all
          # elements).
          # allowlist[:attributes]["th"] = %w(style)
          # allowlist[:attributes]["td"] = %w(style)
          # allowlist[:css] = { properties: ["text-align"] }

          # Allow `id` in a and li elements for footnotes
          # and remove any `id` properties not matching for footnotes
          allowlist[:attributes]["a"].push "id"
          allowlist[:attributes]["li"] = %w(id)
          allowlist[:transformers].push lambda{|env|
            node = env[:node]
            return unless node.name == "a" || node.name == "li"
            return unless node.has_attribute?("id")
            return if node.name == "a" && node["id"] =~ /\Afnref-\d+\z/
            return if node.name == "li" && node["id"] =~ /\Afn-\d+\z/

            node.remove_attribute("id")
          }

          # https://github.com/rgrove/sanitize/issues/209
          allowlist[:protocols].delete("a")
          allowlist[:transformers].push lambda{|env|
            node = env[:node]
            return if node.type != Nokogiri::XML::Node::ELEMENT_NODE

            name = env[:node_name]
            return unless RELAXED_PROTOCOL_ATTRS.include?(name)

            RELAXED_PROTOCOL_ATTRS[name].each do |attr|
              next unless node.has_attribute?(attr)

              node[attr] = node[attr].strip
              unless !node[attr].empty? && uri_with_link_safe_scheme?(node[attr])
                node.remove_attribute(attr)
              end
            end
          }

          allowlist
        end
      end
    end
  end
end
