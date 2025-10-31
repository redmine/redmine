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
    module CommonMark
      # sanitizes rendered HTML using the Sanitize gem
      class SanitizationFilter
        include Redmine::Helpers::URL

        attr_accessor :allowlist

        LISTS     = Set.new(%w[ul ol].freeze)
        LIST_ITEM = 'li'

        # List of table child elements. These must be contained by a <table> element
        # or they are not allowed through. Otherwise they can be used to break out
        # of places we're using tables to contain formatted user content (like pull
        # request review comments).
        TABLE_ITEMS = Set.new(%w[tr td th].freeze)
        TABLE = 'table'
        TABLE_SECTIONS = Set.new(%w[thead tbody tfoot].freeze)

        # The main sanitization allowlist. Only these elements and attributes are
        # allowed through by default.
        ALLOWLIST = {
          :elements => %w[
            h1 h2 h3 h4 h5 h6 br b i strong em a pre code img input tt u
            div ins del sup sub p ol ul table thead tbody tfoot blockquote
            dl dt dd kbd q samp var hr ruby rt rp li tr td th s strike summary
            details caption figure figcaption
            abbr bdo cite dfn mark small span time wbr
          ].freeze,
            :remove_contents => ['script'].freeze,
            :attributes => {
              'a'          => %w[href id name].freeze,
              'img'        => %w[src longdesc].freeze,
              'code'       => ['class'].freeze,
              'div'        => %w[class itemscope itemtype].freeze,
              'li'         => %w[id class].freeze,
              'input'      => %w[class type].freeze,
              'p'          => ['class'].freeze,
              'ul'         => ['class'].freeze,
              'blockquote' => ['cite'].freeze,
              'del'        => ['cite'].freeze,
              'ins'        => ['cite'].freeze,
              'q'          => ['cite'].freeze,
              :all => %w[
                abbr accept accept-charset
                accesskey action align alt
                aria-describedby aria-hidden aria-label aria-labelledby
                axis border cellpadding cellspacing char
                charoff charset checked
                clear cols colspan color
                compact coords datetime dir
                disabled enctype for frame
                headers height hreflang
                hspace ismap label lang
                maxlength media method
                multiple nohref noshade
                nowrap open progress prompt readonly rel rev
                role rows rowspan rules scope
                selected shape size span
                start style summary tabindex target
                title type usemap valign value
                vspace width itemprop
              ].freeze
            }.freeze,
            :protocols => {
              'blockquote' => { 'cite' => ['http', 'https', :relative].freeze },
              'del'        => { 'cite' => ['http', 'https', :relative].freeze },
              'ins'        => { 'cite' => ['http', 'https', :relative].freeze },
              'q'          => { 'cite' => ['http', 'https', :relative].freeze },
              'img'        => {
                'src'      => ['http', 'https', :relative].freeze,
                'longdesc' => ['http', 'https', :relative].freeze
              }.freeze
            },
            :transformers => [
              # Top-level <li> elements are removed because they can break out of
              # containing markup.
              lambda { |env|
                name = env[:node_name]
                node = env[:node]
                if name == LIST_ITEM && node.ancestors.none? { |n| LISTS.include?(n.name) }
                  node.replace(node.children)
                end
              },

              # Table child elements that are not contained by a <table> are removed.
              lambda { |env|
                name = env[:node_name]
                node = env[:node]
                if (TABLE_SECTIONS.include?(name) || TABLE_ITEMS.include?(name)) && node.ancestors.none? { |n| n.name == TABLE }
                  node.replace(node.children)
                end
              }
            ].freeze,
            :css => {
              :properties => %w[
                color background-color
                width min-width max-width
                height min-height max-height
                padding padding-left padding-right padding-top padding-bottom
                margin margin-left margin-right margin-top margin-bottom
                border border-left border-right border-top border-bottom border-radius border-style border-collapse border-spacing
                font font-style font-variant font-weight font-stretch font-size line-height font-family
                text-align
                float
              ].freeze
            }
        }.freeze

        RELAXED_PROTOCOL_ATTRS = {
          "a" => %w(href).freeze,
        }.freeze

        def initialize
          @allowlist = default_allowlist
          add_transformers
        end

        def call(doc)
          # Sanitize is applied to the whole document, so the API is different from loofeh's scrubber.
          Sanitize.clean_node!(doc, allowlist)
        end

        private

        def add_transformers
          # allow class on code tags (this holds the language info from fenced
          # code bocks and has the format language-foo)
          allowlist[:transformers].push lambda {|env|
            node = env[:node]
            return unless node.name == "code"
            return unless node.has_attribute?("class")

            unless /\Alanguage-(\S+)\z/.match?(node["class"])
              node.remove_attribute("class")
            end
          }

          # Allow class on div and p tags only for alert blocks
          # (must be exactly: "markdown-alert markdown-alert-*" for div, and "markdown-alert-title" for p)
          allowlist[:transformers].push lambda {|env|
            node = env[:node]
            return unless node.element?

            case node.name
            when 'div'
              unless /\Amarkdown-alert markdown-alert-[a-z]+\z/.match?(node['class'])
                node.remove_attribute('class')
              end
            when 'p'
              unless node['class'] == 'markdown-alert-title'
                node.remove_attribute('class')
              end
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

          # Remove any `id` property not matching for footnotes
          allowlist[:transformers].push lambda {|env|
            node = env[:node]
            return unless node.name == "a"
            return unless node.has_attribute?("id")
            return if node.name == "a" && node["id"] =~ /\Afnref(-\d+){1,2}\z/

            node.remove_attribute("id")
          }

          # allow `id` in li element for footnotes
          # allow `class` in li element for task list items
          allowlist[:transformers].push lambda {|env|
            node = env[:node]
            return unless node.name == "li"

            if node.has_attribute?("id") && !(node["id"] =~ /\Afn-\d+\z/)
              node.remove_attribute("id")
            end

            if node.has_attribute?("class") && node["class"] != "task-list-item"
              node.remove_attribute("class")
            end
          }

          # allow input type = "checkbox" with class "task-list-item-checkbox"
          # for task list items
          allowlist[:transformers].push lambda {|env|
            node = env[:node]
            return unless node.name == "input"
            return if node['type'] == "checkbox" && node['class'] == "task-list-item-checkbox"

            node.replace(node.children)
          }

          # allow class "contains-task-list" on ul for task list items
          allowlist[:transformers].push lambda {|env|
            node = env[:node]
            return unless node.name == "ul"
            return if node["class"] == "contains-task-list"

            node.remove_attribute("class")
          }

          # https://github.com/rgrove/sanitize/issues/209
          allowlist[:transformers].push lambda {|env|
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
        end

        # The allowlist to use when sanitizing. This can be passed in the context
        # hash to the filter but defaults to ALLOWLIST constant value above.
        def default_allowlist
          ALLOWLIST.deep_dup
        end
      end
    end
  end
end
