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
  # Class used to parse unified diffs
  class UnifiedDiff < Array
    attr_reader :diff_type, :diff_style

    def initialize(diff, options={})
      super()
      options.assert_valid_keys(:type, :style, :max_lines)
      diff = diff.split("\n") if diff.is_a?(String)
      @diff_type = options[:type] || 'inline'
      @diff_style = options[:style]
      # remove git footer
      if diff.length > 1 &&
           diff[-2] =~ /^--/ &&
           diff[-1] =~ /^[0-9]/
        diff.pop(2)
      end
      lines = 0
      @truncated = false
      diff_table = DiffTable.new(diff_type, diff_style)
      diff.each do |line_raw|
        line = Redmine::CodesetUtil.to_utf8_by_setting(line_raw)
        unless diff_table.add_line(line)
          self << diff_table if diff_table.length > 0
          diff_table = DiffTable.new(diff_type, diff_style)
        end
        lines += 1
        if options[:max_lines] && lines > options[:max_lines]
          @truncated = true
          break
        end
      end
      self << diff_table unless diff_table.empty?
      self
    end

    def truncated?; @truncated; end
  end
end
