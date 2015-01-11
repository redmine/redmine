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

require File.expand_path('../../test_helper', __FILE__)

class BoardTest < ActiveSupport::TestCase
  fixtures :projects, :boards, :messages, :attachments, :watchers

  include Redmine::I18n

  def setup
    @project = Project.find(1)
  end

  def test_create
    board = Board.new(:project => @project, :name => 'Test board', :description => 'Test board description')
    assert board.save
    board.reload
    assert_equal 'Test board', board.name
    assert_equal 'Test board description', board.description
    assert_equal @project, board.project
    assert_equal 0, board.topics_count
    assert_equal 0, board.messages_count
    assert_nil board.last_message
    # last position
    assert_equal @project.boards.size, board.position
  end

  def test_parent_should_be_in_same_project
    set_language_if_valid 'en'
    board = Board.new(:project_id => 3, :name => 'Test', :description => 'Test', :parent_id => 1)
    assert !board.save
    assert_include "Parent forum is invalid", board.errors.full_messages
  end

  def test_valid_parents_should_not_include_self_nor_a_descendant
    board1 = Board.generate!(:project_id => 3)
    board2 = Board.generate!(:project_id => 3, :parent => board1)
    board3 = Board.generate!(:project_id => 3, :parent => board2)
    board4 = Board.generate!(:project_id => 3)

    assert_equal [board4], board1.reload.valid_parents.sort_by(&:id)
    assert_equal [board1, board4], board2.reload.valid_parents.sort_by(&:id)
    assert_equal [board1, board2, board4], board3.reload.valid_parents.sort_by(&:id)
    assert_equal [board1, board2, board3], board4.reload.valid_parents.sort_by(&:id)
  end

  def test_position_should_be_assigned_with_parent_scope
    parent1 = Board.generate!(:project_id => 3)
    parent2 = Board.generate!(:project_id => 3)
    child1 = Board.generate!(:project_id => 3, :parent => parent1)
    child2 = Board.generate!(:project_id => 3, :parent => parent1)

    assert_equal 1, parent1.reload.position
    assert_equal 1, child1.reload.position
    assert_equal 2, child2.reload.position
    assert_equal 2, parent2.reload.position
  end

  def test_board_tree_should_yield_boards_with_level
    parent1 = Board.generate!(:project_id => 3)
    parent2 = Board.generate!(:project_id => 3)
    child1 = Board.generate!(:project_id => 3, :parent => parent1)
    child2 = Board.generate!(:project_id => 3, :parent => parent1)
    child3 = Board.generate!(:project_id => 3, :parent => child1)

    tree = Board.board_tree(Project.find(3).boards)

    assert_equal [
      [parent1, 0],
      [child1,  1],
      [child3,  2],
      [child2,  1],
      [parent2, 0]
    ], tree
  end

  def test_destroy
    board = Board.find(1)
    assert_difference 'Message.count', -6 do
      assert_difference 'Attachment.count', -1 do
        assert_difference 'Watcher.count', -1 do
          assert board.destroy
        end
      end
    end
    assert_equal 0, Message.where(:board_id => 1).count
  end

  def test_destroy_should_nullify_children
    parent = Board.generate!(:project => @project)
    child = Board.generate!(:project => @project, :parent => parent)
    assert_equal parent, child.parent

    assert parent.destroy
    child.reload
    assert_nil child.parent
    assert_nil child.parent_id
  end

  def test_reset_counters_should_update_attributes
    Board.where(:id => 1).update_all(:topics_count => 0, :messages_count => 0, :last_message_id => 0)
    Board.reset_counters!(1)
    board = Board.find(1)
    assert_equal board.topics.count, board.topics_count
    assert_equal board.messages.count, board.messages_count
    assert_equal board.messages.order("id DESC").first.id, board.last_message_id
  end
end
