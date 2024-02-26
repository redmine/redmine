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

# Class that represents a file diff
module Redmine
  class DiffTable < Array
    attr_reader :file_name, :previous_file_name

    # Initialize with a Diff file and the type of Diff View
    # The type view must be inline or sbs (side_by_side)
    def initialize(type="inline", style=nil)
      super()
      @parsing = false
      @added = 0
      @removed = 0
      @type = type
      @style = style
      @file_name = nil
      @previous_file_name = nil
      @git_diff = false
    end

    # Function for add a line of this Diff
    # Returns false when the diff ends
    def add_line(line)
      unless @parsing
        if line =~ /^(---|\+\+\+) (.*)$/
          self.file_name = $2
        elsif line =~ /^@@ (\+|\-)(\d+)(,\d+)? (\+|\-)(\d+)(,\d+)? @@/
          @line_num_l = $2.to_i
          @line_num_r = $5.to_i
          @parsing = true
        end
      else
        if %r{^[^\+\-\s@\\]}.match?(line)
          @parsing = false
          return false
        elsif line =~ /^@@ (\+|\-)(\d+)(,\d+)? (\+|\-)(\d+)(,\d+)? @@/
          @line_num_l = $2.to_i
          @line_num_r = $5.to_i
        else
          parse_line(line, @type)
        end
      end
      return true
    end

    def each_line
      prev_line_left, prev_line_right = nil, nil
      each do |line|
        spacing = prev_line_left && prev_line_right && (line.nb_line_left != prev_line_left+1) && (line.nb_line_right != prev_line_right+1)
        yield spacing, line
        prev_line_left = line.nb_line_left.to_i if line.nb_line_left.to_i > 0
        prev_line_right = line.nb_line_right.to_i if line.nb_line_right.to_i > 0
      end
    end

    def inspect
      puts '### DIFF TABLE ###'
      puts "file : #{file_name}"
      self.each do |d|
        d.inspect
      end
    end

    private

    def file_name=(arg)
      both_git_diff = false
      if file_name.nil?
        @git_diff = true if %r{^(a/|/dev/null)}.match?(arg)
      else
        both_git_diff = (@git_diff && %r{^(b/|/dev/null)}.match?(arg))
      end
      if both_git_diff
        if file_name && arg == "/dev/null"
          # keep the original file name
          @file_name = file_name.delete_prefix('a/')
        else
          # remove leading a/
          @previous_file_name = file_name.delete_prefix('a/') unless file_name == "/dev/null"
          # remove leading b/
          @file_name = arg.delete_prefix('b/')

          @previous_file_name = nil if @previous_file_name == @file_name
        end
      elsif @style == "Subversion"
        # removing trailing "(revision nn)"
        @file_name = arg.sub(%r{\t+\(.*\)$}, '')
      else
        @file_name = arg
      end
    end

    def diff_for_added_line
      if @type == 'sbs' && @removed > 0 && @added < @removed
        self[-(@removed - @added)]
      else
        diff = Diff.new
        self << diff
        diff
      end
    end

    def parse_line(line, type="inline")
      if line.start_with?('+')
        diff = diff_for_added_line
        diff.line_right = line[1..-1]
        diff.nb_line_right = @line_num_r
        diff.type_diff_right = 'diff_in'
        @line_num_r += 1
        @added += 1
        true
      elsif line.start_with?('-')
        diff = Diff.new
        diff.line_left = line[1..-1]
        diff.nb_line_left = @line_num_l
        diff.type_diff_left = 'diff_out'
        self << diff
        @line_num_l += 1
        @removed += 1
        true
      else
        write_offsets
        if line.start_with?(/\s/)
          diff = Diff.new
          diff.line_right = line[1..-1]
          diff.nb_line_right = @line_num_r
          diff.line_left = line[1..-1]
          diff.nb_line_left = @line_num_l
          self << diff
          @line_num_l += 1
          @line_num_r += 1
          true
        elsif line[0, 1] = "\\"
          true
        else
          false
        end
      end
    end

    def write_offsets
      if @added > 0 && @added == @removed
        @added.times do |i|
          line = self[-(1 + i)]
          removed = (@type == 'sbs') ? line : self[-(1 + @added + i)]
          offsets = offsets(removed.line_left, line.line_right)
          removed.offsets = line.offsets = offsets
        end
      end
      @added = 0
      @removed = 0
    end

    def offsets(line_left, line_right)
      if line_left.present? && line_right.present? && line_left != line_right
        max = [line_left.size, line_right.size].min
        starting = 0
        while starting < max &&
                line_left[starting] == line_right[starting]
          starting += 1
        end
        ending = -1
        while ending >= -(max - starting) &&
               (line_left[ending] == line_right[ending])
          ending -= 1
        end
        unless starting == 0 && ending == -1
          [starting, ending]
        end
      end
    end
  end
end
