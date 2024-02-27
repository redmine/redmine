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

class WikiAnnotate
  attr_reader :lines, :content

  def initialize(content)
    @content = content
    current = content
    current_lines = current.text.split(/\r?\n/)
    @lines = current_lines.collect {|t| [nil, nil, t]}
    positions = []
    current_lines.size.times {|i| positions << i}
    while current.previous
      d = current.previous.text.split(/\r?\n/).diff(current.text.split(/\r?\n/)).diffs.flatten
      d.each_slice(3) do |s|
        sign, line = s[0], s[1]
        if sign == '+' && positions[line] && positions[line] != -1
          if @lines[positions[line]][0].nil?
            @lines[positions[line]][0] = current.version
            @lines[positions[line]][1] = current.author
          end
        end
      end
      d.each_slice(3) do |s|
        sign, line = s[0], s[1]
        if sign == '-'
          positions.insert(line, -1)
        else
          positions[line] = nil
        end
      end
      positions.compact!
      # Stop if every line is annotated
      break unless @lines.detect {|line| line[0].nil?}

      current = current.previous
    end
    @lines.each do |line|
      line[0] ||= current.version
      # if the last known version is > 1 (eg. history was cleared), we don't know the author
      line[1] ||= current.author if current.version == 1
    end
  end
end
