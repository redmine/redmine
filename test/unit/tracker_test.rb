# Redmine - project management software
# Copyright (C) 2006-2008  Jean-Philippe Lang
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

class TrackerTest < ActiveSupport::TestCase
  fixtures :trackers, :workflows, :issue_statuses, :roles, :issues

  def test_sorted_scope
    assert_equal Tracker.all.sort, Tracker.sorted.to_a
  end

  def test_named_scope
    assert_equal Tracker.find_by_name('Feature'), Tracker.named('feature').first
  end

  def test_copy_workflows
    source = Tracker.find(1)
    assert_equal 89, source.workflow_rules.size

    target = Tracker.new(:name => 'Target', :default_status_id => 1)
    assert target.save
    target.workflow_rules.copy(source)
    target.reload
    assert_equal 89, target.workflow_rules.size
  end

  def test_issue_statuses
    tracker = Tracker.find(1)
    WorkflowTransition.delete_all
    WorkflowTransition.create!(:role_id => 1, :tracker_id => 1, :old_status_id => 2, :new_status_id => 3)
    WorkflowTransition.create!(:role_id => 2, :tracker_id => 1, :old_status_id => 3, :new_status_id => 5)

    assert_kind_of Array, tracker.issue_statuses
    assert_kind_of IssueStatus, tracker.issue_statuses.first
    assert_equal [2, 3, 5], Tracker.find(1).issue_statuses.collect(&:id)
  end

  def test_issue_statuses_empty
    WorkflowTransition.delete_all("tracker_id = 1")
    assert_equal [], Tracker.find(1).issue_statuses
  end

  def test_issue_statuses_should_be_empty_for_new_record
    assert_equal [], Tracker.new.issue_statuses
  end

  def test_core_fields_should_be_enabled_by_default
    tracker = Tracker.new
    assert_equal Tracker::CORE_FIELDS, tracker.core_fields
    assert_equal [], tracker.disabled_core_fields
  end

  def test_core_fields
    tracker = Tracker.new
    tracker.core_fields = %w(assigned_to_id due_date)

    assert_equal %w(assigned_to_id due_date), tracker.core_fields
    assert_equal Tracker::CORE_FIELDS - %w(assigned_to_id due_date), tracker.disabled_core_fields
  end

  def test_core_fields_should_return_fields_enabled_for_any_tracker
    trackers = []
    trackers << Tracker.new(:core_fields => %w(assigned_to_id due_date))
    trackers << Tracker.new(:core_fields => %w(assigned_to_id done_ratio))
    trackers << Tracker.new(:core_fields => [])

    assert_equal %w(assigned_to_id due_date done_ratio), Tracker.core_fields(trackers)
    assert_equal Tracker::CORE_FIELDS - %w(assigned_to_id due_date done_ratio), Tracker.disabled_core_fields(trackers)
  end

  def test_core_fields_should_return_all_fields_for_an_empty_argument
    assert_equal Tracker::CORE_FIELDS, Tracker.core_fields([])
    assert_equal [], Tracker.disabled_core_fields([])
  end

  def test_sort_should_sort_by_position
    a = Tracker.new(:name => 'Tracker A', :position => 2)
    b = Tracker.new(:name => 'Tracker B', :position => 1)

    assert_equal [b, a], [a, b].sort
  end

  def test_destroying_a_tracker_without_issues_should_not_raise_an_error
    tracker = Tracker.find(1)
    Issue.delete_all :tracker_id => tracker.id

    assert_difference 'Tracker.count', -1 do
      assert_nothing_raised do
        tracker.destroy
      end
    end
  end

  def test_destroying_a_tracker_with_issues_should_raise_an_error
    tracker = Tracker.find(1)

    assert_no_difference 'Tracker.count' do
      assert_raise Exception do
        tracker.destroy
      end
    end
  end
end
