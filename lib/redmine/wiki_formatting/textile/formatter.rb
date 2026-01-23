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
      SCRUBBERS = [
        SyntaxHighlightScrubber.new,
        Redmine::WikiFormatting::TablesortScrubber.new,
        Redmine::WikiFormatting::CopypreScrubber.new
      ]

      class Formatter
        include Redmine::WikiFormatting::SectionHelper

        extend Forwardable
        def_delegators :@filter, :extract_sections, :rip_offtags

        def initialize(args)
          @filter = Filter.new(args)
        end

        def to_html(*rules)
          html = @filter.to_html(rules)
          fragment = Loofah.html5_fragment(html)
          SCRUBBERS.each do |scrubber|
            fragment.scrub!(scrubber)
          end
          fragment.to_s
        end
      end

      class Filter < RedCloth3
        include Redmine::WikiFormatting::LinksHelper

        alias :inline_auto_link :auto_link!
        alias :inline_auto_mailto :auto_mailto!
        alias :inline_restore_redmine_links :restore_redmine_links

        # auto_link rule after textile rules so that it doesn't break !image_url! tags
        RULES = [:textile, :block_markdown_rule, :inline_auto_link, :inline_auto_mailto, :inline_restore_redmine_links]

        def initialize(*args)
          super
          self.hard_breaks=true
          self.no_span_caps=true
          self.filter_styles=false
        end

        def to_html(*rules)
          @toc = []
          super(*RULES)
        end

        def extract_sections(index)
          @pre_list = []
          text = self.dup
          rip_offtags text, false, false
          before = +''
          s = +''
          after = +''
          i = 0
          l = 1
          started = false
          ended = false
          text.scan(/(((?:.*?)(\A|\r?\n\s*\r?\n))(h(\d+)(#{A}#{C})\.(?::(\S+))?[ \t](.*?)$)|.*)/mo).each do |all, content, lf, heading, level|
            if heading.nil?
              if ended
                after << all
              elsif started
                s << all
              else
                before << all
              end
              break
            end
            i += 1
            if ended
              after << all
            elsif i == index
              l = level.to_i
              before << content
              s << heading
              started = true
            elsif i > index
              s << content
              if level.to_i > l
                s << heading
              else
                after << heading
                ended = true
              end
            else
              before << all
            end
          end
          sections = [before.strip, s.strip, after.strip]
          sections.each {|section| smooth_offtags section}
          sections
        end

        private

        # Patch for RedCloth.  Fixed in RedCloth r128 but _why hasn't released it yet.
        # <a href="http://code.whytheluckystiff.net/redcloth/changeset/128">http://code.whytheluckystiff.net/redcloth/changeset/128</a>
        def hard_break(text)
          text.gsub!(/(.)\n(?!\n|\Z| *([#*=]+(\s|$)|[{|]))/, "\\1<br />") if hard_breaks
        end
      end
    end
  end
end
