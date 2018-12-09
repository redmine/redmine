# Redmine - project management software
# Copyright (C) 2006-2017  Jean-Philippe Lang
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

require File.expand_path('../../../../../test_helper', __FILE__)

class Redmine::Acts::PositionedWithScopeTest < ActiveSupport::TestCase
  fixtures :projects, :boards

  def test_create_should_default_to_last_position
    b = Board.generate!(:project_id => 1)
    assert_equal 3, b.reload.position

    b = Board.generate!(:project_id => 3)
    assert_equal 1, b.reload.position
  end

  def test_create_should_insert_at_given_position
    b = Board.generate!(:project_id => 1, :position => 2)

    assert_equal 2, b.reload.position
    assert_equal [1, 3, 1, 2], Board.order(:id).pluck(:position)
  end

  def test_destroy_should_remove_position
    b = Board.generate!(:project_id => 1, :position => 2)
    b.destroy

    assert_equal [1, 2, 1], Board.order(:id).pluck(:position)
  end

  def test_update_should_update_positions
    b = Board.generate!(:project_id => 1)
    assert_equal 3, b.position

    b.position = 2
    b.save!
    assert_equal [1, 3, 1, 2], Board.order(:id).pluck(:position)
  end
end
