# encoding: utf-8
#
# Redmine - project management software
# Copyright (C) 2006-2015  Jean-Philippe Lang
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

module BoardsHelper
  def board_breadcrumb(item)
    board = item.is_a?(Message) ? item.board : item
    links = [link_to(l(:label_board_plural), project_boards_path(item.project))]
    boards = board.ancestors.reverse
    if item.is_a?(Message)
      boards << board
    end
    links += boards.map {|ancestor| link_to(h(ancestor.name), project_board_path(ancestor.project, ancestor))}
    breadcrumb links
  end

  def boards_options_for_select(boards)
    options = []
    Board.board_tree(boards) do |board, level|
      label = (level > 0 ? '&nbsp;' * 2 * level + '&#187; ' : '').html_safe
      label << board.name
      options << [label, board.id]
    end
    options
  end
end
