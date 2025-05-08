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
    module SectionHelper
      def get_section(index)
        section = extract_sections(index)[1]
        hash = ActiveSupport::Digest.hexdigest(section)
        return section, hash
      end

      def update_section(index, update, hash=nil)
        t = extract_sections(index)
        if hash.present? && hash != ActiveSupport::Digest.hexdigest(t[1])
          raise Redmine::WikiFormatting::StaleSectionError
        end

        t[1] = update unless t[1].blank?
        t.reject(&:blank?).join "\n\n"
      end

      def extract_sections(index)
        sections = [+'', +'', +'']
        offset = 0
        i = 0
        l = 1
        inside_pre = false
        @text.split(/(^(?:\S+\r?\n\r?(?:=+|-+)|#+ .+|(?:~~~|```).*)\s*$)/).each do |part|
          level = nil
          if part =~ /\A(~{3,}|`{3,})(\s*\S+)?\s*$/
            if !inside_pre
              inside_pre = true
            elsif !$2
              inside_pre = false
            end
          elsif inside_pre
            # nop
          elsif part =~ /\A(#+) .+/
            level = $1.size
          elsif part =~ /\A.+\r?\n\r?(=+|-+)\s*$/
            level = $1.include?('=') ? 1 : 2
          end
          if level
            i += 1
            if offset == 0 && i == index
              # entering the requested section
              offset = 1
              l = level
            elsif offset == 1 && i > index && level <= l
              # leaving the requested section
              offset = 2
            end
          end
          sections[offset] << part
        end
        sections.map(&:strip)
      end
    end
  end
end
