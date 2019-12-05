# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2019  Jean-Philippe Lang
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

require File.expand_path('../redcloth3', __FILE__)
require 'digest/md5'

module Redmine
  module WikiFormatting
    module Textile
      class Formatter < RedCloth3
        include ActionView::Helpers::TagHelper
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
          super(*RULES).to_s
        end

        def get_section(index)
          section = extract_sections(index)[1]
          hash = Digest::MD5.hexdigest(section)
          return section, hash
        end

        def update_section(index, update, hash=nil)
          t = extract_sections(index)
          if hash.present? && hash != Digest::MD5.hexdigest(t[1])
            raise Redmine::WikiFormatting::StaleSectionError
          end
          t[1] = update unless t[1].blank?
          t.reject(&:blank?).join "\n\n"
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
          text.scan(/(((?:.*?)(\A|\r?\n\s*\r?\n))(h(\d+)(#{A}#{C})\.(?::(\S+))?[ \t](.*?)$)|.*)/m).each do |all, content, lf, heading, level|
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
          sections.each {|section| smooth_offtags_without_code_highlighting section}
          sections
        end

        private

        # Patch for RedCloth.  Fixed in RedCloth r128 but _why hasn't released it yet.
        # <a href="http://code.whytheluckystiff.net/redcloth/changeset/128">http://code.whytheluckystiff.net/redcloth/changeset/128</a>
        def hard_break( text )
          text.gsub!( /(.)\n(?!\n|\Z| *([#*=]+(\s|$)|[{|]))/, "\\1<br />" ) if hard_breaks
        end

        alias :smooth_offtags_without_code_highlighting :smooth_offtags
        # Patch to add code highlighting support to RedCloth
        def smooth_offtags( text )
          unless @pre_list.empty?
            ## replace <pre> content
            text.gsub!(/<redpre#(\d+)>/) do
              content = @pre_list[$1.to_i]
              # This regex must match any data produced by RedCloth3#rip_offtags
              if content.match(/<code\s+class=(?:"([^"]+)"|'([^']+)')>\s?(.*)/m)
                language = $1 || $2
                text = $3
                if Redmine::SyntaxHighlighting.language_supported?(language)
                  text.gsub!(/x%x%/, '&')
                  content = "<code class=\"#{language} syntaxhl\">" +
                    Redmine::SyntaxHighlighting.highlight_by_language(text, language)
                else
                  content = "<code>#{ERB::Util.h(text)}"
                end
              end
              content
            end
          end
        end
      end
    end
  end
end
