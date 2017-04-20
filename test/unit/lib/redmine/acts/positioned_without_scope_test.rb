# Redmine - project management software
# Copyright (C) 2006-2016  Jean-Philippe Lang
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

class Redmine::Acts::PositionedWithoutScopeTest < ActiveSupport::TestCase
  fixtures :trackers, :issue_statuses

  def test_create_should_default_to_last_position
    t = Tracker.generate
    t.save!

    assert_equal 4, t.reload.position
  end

  def test_create_should_insert_at_given_position
    t = Tracker.generate
    t.position = 2
    t.save!

    assert_equal 2, t.reload.position
    assert_equal [1, 3, 4, 2], Tracker.order(:id).pluck(:position)
  end

  def test_destroy_should_remove_position
    t = Tracker.generate!
    Tracker.generate!
    t.destroy

    assert_equal [1, 2, 3, 4], Tracker.order(:id).pluck(:position)
  end

  def test_update_should_update_positions
    t = Tracker.generate!
    assert_equal 4, t.position

    t.position = 2
    t.save!
    assert_equal [1, 3, 4, 2], Tracker.order(:id).pluck(:position)
  end
end
