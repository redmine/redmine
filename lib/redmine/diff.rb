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
  # A line of diff
  class Diff
    attr_accessor :nb_line_left
    attr_accessor :line_left
    attr_accessor :nb_line_right
    attr_accessor :line_right
    attr_accessor :type_diff_right
    attr_accessor :type_diff_left
    attr_accessor :offsets

    def initialize
      self.nb_line_left = ''
      self.nb_line_right = ''
      self.line_left = ''
      self.line_right = ''
      self.type_diff_right = ''
      self.type_diff_left = ''
    end

    def type_diff
      type_diff_right == 'diff_in' ? type_diff_right : type_diff_left
    end

    def line
      type_diff_right == 'diff_in' ? line_right : line_left
    end

    def html_line_left
      line_to_html(line_left, offsets)
    end

    def html_line_right
      line_to_html(line_right, offsets)
    end

    def html_line
      line_to_html(line, offsets)
    end

    def inspect
      puts '### Start Line Diff ###'
      puts self.nb_line_left
      puts self.line_left
      puts self.nb_line_right
      puts self.line_right
    end

    private

    def line_to_html(line, offsets)
      html = line_to_html_raw(line, offsets)
      html.force_encoding('UTF-8')
      html
    end

    def line_to_html_raw(line, offsets)
      if offsets
        s = +''
        unless offsets.first == 0
          s << CGI.escapeHTML(line[0..offsets.first-1])
        end
        s << '<span>' + CGI.escapeHTML(line[offsets.first..offsets.last]) + '</span>'
        unless offsets.last == -1
          s << CGI.escapeHTML(line[offsets.last+1..-1])
        end
        s
      else
        CGI.escapeHTML(line)
      end
    end
  end
end
