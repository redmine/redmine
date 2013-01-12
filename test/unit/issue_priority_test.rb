# Redmine - project management software
# Copyright (C) 2006-2013  Jean-Philippe Lang
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

class IssuePriorityTest < ActiveSupport::TestCase
  fixtures :enumerations, :issues

  def test_named_scope
    assert_equal Enumeration.find_by_name('Normal'), Enumeration.named('normal').first
  end

  def test_default_should_return_the_default_priority
    assert_equal Enumeration.find_by_name('Normal'), IssuePriority.default
  end

  def test_default_should_return_nil_when_no_default_priority
    IssuePriority.update_all :is_default => false
    assert_nil IssuePriority.default
  end

  def test_should_be_an_enumeration
    assert IssuePriority.ancestors.include?(Enumeration)
  end

  def test_objects_count
    # low priority
    assert_equal 6, IssuePriority.find(4).objects_count
    # urgent
    assert_equal 0, IssuePriority.find(7).objects_count
  end

  def test_option_name
    assert_equal :enumeration_issue_priorities, IssuePriority.new.option_name
  end

  def test_should_be_created_at_last_position
    IssuePriority.delete_all

    priorities = [1, 2, 3].map {|i| IssuePriority.create!(:name => "P#{i}")}
    assert_equal [1, 2, 3], priorities.map(&:position)
  end

  def test_reset_positions_in_list_should_set_sequential_positions
    IssuePriority.delete_all

    priorities = [1, 2, 3].map {|i| IssuePriority.create!(:name => "P#{i}")}
    priorities[0].update_attribute :position, 4
    priorities[1].update_attribute :position, 2
    priorities[2].update_attribute :position, 7
    assert_equal [4, 2, 7], priorities.map(&:reload).map(&:position)

    priorities[0].reset_positions_in_list
    assert_equal [2, 1, 3], priorities.map(&:reload).map(&:position)
  end

  def test_moving_in_list_should_reset_positions
    priority = IssuePriority.first
    priority.expects(:reset_positions_in_list).once
    priority.move_to = 'higher'
  end

  def test_clear_position_names_should_set_position_names_to_nil
    IssuePriority.clear_position_names
    assert IssuePriority.all.all? {|priority| priority.position_name.nil?}
  end

  def test_compute_position_names_with_default_priority
    IssuePriority.clear_position_names

    IssuePriority.compute_position_names
    assert_equal %w(lowest default high3 high2 highest), IssuePriority.active.all.sort.map(&:position_name)
  end

  def test_compute_position_names_without_default_priority_should_split_priorities
    IssuePriority.clear_position_names
    IssuePriority.update_all :is_default => false

    IssuePriority.compute_position_names
    assert_equal %w(lowest low2 default high2 highest), IssuePriority.active.all.sort.map(&:position_name)
  end

  def test_adding_a_priority_should_update_position_names
    priority = IssuePriority.create!(:name => 'New')
    assert_equal %w(lowest default high4 high3 high2 highest), IssuePriority.active.all.sort.map(&:position_name)
  end

  def test_destroying_a_priority_should_update_position_names
    IssuePriority.find_by_position_name('highest').destroy
    assert_equal %w(lowest default high2 highest), IssuePriority.active.all.sort.map(&:position_name)
  end
end
