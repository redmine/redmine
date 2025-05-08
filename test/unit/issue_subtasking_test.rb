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

require_relative '../test_helper'

class IssueSubtaskingTest < ActiveSupport::TestCase
  def setup
    User.current = nil
  end

  def test_leaf_planning_fields_should_be_editable
    issue = Issue.generate!
    user = User.find(1)
    %w(priority_id done_ratio start_date due_date estimated_hours).each do |attribute|
      assert issue.safe_attribute?(attribute, user)
    end
  end

  def test_parent_dates_should_be_read_only_with_parent_issue_dates_set_to_derived
    with_settings :parent_issue_dates => 'derived' do
      issue = Issue.generate_with_child!
      user = User.find(1)
      %w(start_date due_date).each do |attribute|
        assert !issue.safe_attribute?(attribute, user)
      end
    end
  end

  def test_parent_dates_should_be_lowest_start_and_highest_due_dates_with_parent_issue_dates_set_to_derived
    with_settings :parent_issue_dates => 'derived' do
      parent = Issue.generate!
      parent.generate_child!(:start_date => '2010-01-25', :due_date => '2010-02-15')
      parent.generate_child!(:due_date => '2010-02-13')
      parent.generate_child!(:start_date => '2010-02-01', :due_date => '2010-02-22')
      parent.reload
      assert_equal Date.parse('2010-01-25'), parent.start_date
      assert_equal Date.parse('2010-02-22'), parent.due_date
    end
  end

  def test_reschuling_a_parent_should_reschedule_subtasks_with_parent_issue_dates_set_to_derived
    with_settings :parent_issue_dates => 'derived' do
      parent = Issue.generate!
      c1 = parent.generate_child!(:start_date => '2010-05-12', :due_date => '2010-05-18')
      c2 = parent.generate_child!(:start_date => '2010-06-03', :due_date => '2010-06-10')
      parent.reload.reschedule_on!(Date.parse('2010-06-02'))
      c1.reload
      assert_equal [Date.parse('2010-06-02'), Date.parse('2010-06-08')], [c1.start_date, c1.due_date]
      c2.reload
      assert_equal [Date.parse('2010-06-03'), Date.parse('2010-06-10')], [c2.start_date, c2.due_date] # no change
      parent.reload
      assert_equal [Date.parse('2010-06-02'), Date.parse('2010-06-10')], [parent.start_date, parent.due_date]
    end
  end

  def test_parent_priority_should_be_read_only_with_parent_issue_priority_set_to_derived
    with_settings :parent_issue_priority => 'derived' do
      issue = Issue.generate_with_child!
      user = User.find(1)
      assert !issue.safe_attribute?('priority_id', user)
    end
  end

  def test_parent_priority_should_be_the_highest_open_child_priority
    with_settings :parent_issue_priority => 'derived' do
      parent = Issue.generate!(:priority => IssuePriority.find_by_name('Normal'))
      # Create children
      child1 = parent.generate_child!(:priority => IssuePriority.find_by_name('High'))
      assert_equal 'High', parent.reload.priority.name
      child2 = child1.generate_child!(:priority => IssuePriority.find_by_name('Immediate'))
      assert_equal 'Immediate', child1.reload.priority.name
      assert_equal 'Immediate', parent.reload.priority.name
      child3 = parent.generate_child!(:priority => IssuePriority.find_by_name('Low'))
      child4 = parent.generate_child!(:priority => IssuePriority.find_by_name('Urgent'))
      assert_equal 'Immediate', parent.reload.priority.name
      # Destroy a child
      child1.destroy
      assert_equal 'Urgent', parent.reload.priority.name
      # Close a child
      child4.status = IssueStatus.where(:is_closed => true).first
      child4.save!
      assert_equal 'Low', parent.reload.priority.name
      # Update a child
      child3.reload.priority = IssuePriority.find_by_name('Normal')
      child3.save!
      assert_equal 'Normal', parent.reload.priority.name
      # Reopen a child
      child4.status = IssueStatus.where(:is_closed => false).first
      child4.save!
      assert_equal 'Urgent', parent.reload.priority.name
    end
  end

  def test_parent_priority_should_be_set_to_default_when_all_children_are_closed
    with_settings :parent_issue_priority => 'derived' do
      parent = Issue.generate!
      child = parent.generate_child!(:priority => IssuePriority.find_by_name('High'))
      assert_equal 'High', parent.reload.priority.name
      child.status = IssueStatus.where(:is_closed => true).first
      child.save!
      assert_equal 'Normal', parent.reload.priority.name
    end
  end

  def test_parent_priority_should_be_left_unchanged_when_all_children_are_closed_and_no_default_priority
    IssuePriority.update_all :is_default => false

    with_settings :parent_issue_priority => 'derived' do
      parent = Issue.generate!(:priority => IssuePriority.find_by_name('Normal'))
      child = parent.generate_child!(:priority => IssuePriority.find_by_name('High'))
      assert_equal 'High', parent.reload.priority.name
      child.status = IssueStatus.where(:is_closed => true).first
      child.save!
      assert_equal 'High', parent.reload.priority.name
    end
  end

  def test_parent_done_ratio_should_be_read_only_with_parent_issue_done_ratio_set_to_derived
    with_settings :parent_issue_done_ratio => 'derived' do
      issue = Issue.generate_with_child!
      user = User.find(1)
      assert !issue.safe_attribute?('done_ratio', user)
    end
  end

  def test_parent_done_ratio_should_be_average_done_ratio_of_leaves
    with_settings :parent_issue_done_ratio => 'derived' do
      parent = Issue.generate!
      parent.generate_child!(:done_ratio => 20)
      assert_equal 20, parent.reload.done_ratio
      parent.generate_child!(:done_ratio => 70)
      assert_equal 45, parent.reload.done_ratio

      child = parent.generate_child!(:done_ratio => 0)
      assert_equal 30, parent.reload.done_ratio

      child.generate_child!(:done_ratio => 30)
      assert_equal 30, child.reload.done_ratio
      assert_equal 40, parent.reload.done_ratio
    end
  end

  def test_parent_done_ratio_should_be_rounded_down_to_the_nearest_integer
    with_settings :parent_issue_done_ratio => 'derived' do
      parent = Issue.generate!
      parent.generate_child!(:done_ratio => 20)
      parent.generate_child!(:done_ratio => 20)
      parent.generate_child!(:done_ratio => 10)
      # (20 + 20 + 10) / 3 = 16.666...
      assert_equal 16, parent.reload.done_ratio
    end
  end

  def test_parent_done_ratio_should_be_weighted_by_estimated_times_if_any
    with_settings :parent_issue_done_ratio => 'derived' do
      parent = Issue.generate!
      parent.generate_child!(:estimated_hours => 10, :done_ratio => 20)
      assert_equal 20, parent.reload.done_ratio
      parent.generate_child!(:estimated_hours => 20, :done_ratio => 50)
      assert_equal (50 * 20 + 20 * 10) / 30, parent.reload.done_ratio
    end
  end

  def test_parent_done_ratio_should_be_weighted_by_estimated_times_if_any_with_grandchildren
    # parent
    #   child 1 (2h estd, 0% done)
    #   child 2 (no estd)
    #     child a (2h estd, 50% done)
    #     child b (2h estd, 50% done)
    #
    # => parent should have a calculated progress of 33%
    #
    with_settings :parent_issue_done_ratio => 'derived' do
      parent = Issue.generate!
      parent.generate_child!(:estimated_hours => 2, :done_ratio => 0)
      child = parent.generate_child!
      child.generate_child!(:estimated_hours => 2, :done_ratio => 50)
      child.generate_child!(:estimated_hours => 2, :done_ratio => 50)
      assert_equal 50, child.reload.done_ratio
      assert_equal 33, parent.reload.done_ratio
    end
  end

  def test_parent_done_ratio_with_child_estimate_to_0_should_reach_100
    with_settings :parent_issue_done_ratio => 'derived' do
      parent = Issue.generate!
      issue1 = parent.generate_child!
      issue2 = parent.generate_child!(:estimated_hours => 0)
      assert_equal 0, parent.reload.done_ratio
      issue1.reload.close!
      assert_equal 50, parent.reload.done_ratio
      issue2.reload.close!
      assert_equal 100, parent.reload.done_ratio
    end
  end

  def test_done_ratio_of_parent_with_a_child_without_estimated_time_should_not_exceed_100
    with_settings :parent_issue_done_ratio => 'derived' do
      parent = Issue.generate!
      parent.generate_child!(:estimated_hours => 40)
      parent.generate_child!(:estimated_hours => 40)
      parent.generate_child!(:estimated_hours => 20)
      parent.generate_child!
      parent.reload.children.each(&:close!)
      assert_equal 100, parent.reload.done_ratio
    end
  end

  def test_done_ratio_of_parent_with_a_child_with_estimated_time_at_0_should_not_exceed_100
    with_settings :parent_issue_done_ratio => 'derived' do
      parent = Issue.generate!
      parent.generate_child!(:estimated_hours => 40)
      parent.generate_child!(:estimated_hours => 40)
      parent.generate_child!(:estimated_hours => 20)
      parent.generate_child!(:estimated_hours => 0)
      parent.reload.children.each(&:close!)
      assert_equal 100, parent.reload.done_ratio
    end
  end

  def test_done_ratio_of_parent_with_completed_children_should_not_be_99
    with_settings :parent_issue_done_ratio => 'derived' do
      parent1 = Issue.generate!
      parent1.generate_child!(:estimated_hours => 8.0, :done_ratio => 100)
      parent1.generate_child!(:estimated_hours => 8.1, :done_ratio => 100)
      # (8.0 * 100 + 8.1 * 100) / (8.0 + 8.1) => 99.99999999999999
      assert_equal 100, parent1.reload.done_ratio

      parent2 = Issue.generate!
      parent2.generate_child!(:estimated_hours => 9.0, :done_ratio => 100)
      10.times do
        parent2.generate_child!(:estimated_hours => 10.0, :done_ratio => 100)
      end
      assert_equal 100, parent2.reload.done_ratio
    end
  end

  def test_changing_parent_should_update_previous_parent_done_ratio
    with_settings :parent_issue_done_ratio => 'derived' do
      first_parent = Issue.generate!
      second_parent = Issue.generate!
      first_parent.generate_child!(:done_ratio => 40)
      child = first_parent.generate_child!(:done_ratio => 20)
      assert_equal 30, first_parent.reload.done_ratio
      assert_equal 0, second_parent.reload.done_ratio
      child.update(:parent_issue_id => second_parent.id)
      assert_equal 40,  first_parent.reload.done_ratio
      assert_equal 20, second_parent.reload.done_ratio
    end
  end

  def test_done_ratio_of_parent_should_reflect_children
    root = Issue.generate!
    child1 = root.generate_child!
    child2 = child1.generate_child!

    assert_equal 0, root.done_ratio
    assert_equal 0, child1.done_ratio
    assert_equal 0, child2.done_ratio

    with_settings :issue_done_ratio => 'issue_status' do
      status = IssueStatus.find(4)
      status.update_attribute :default_done_ratio, 50
      child1.reload
      child1.update_attribute :status, status

      assert_equal 50, child1.done_ratio
      root.reload
      assert_equal 50, root.done_ratio
    end
  end

  def test_parent_dates_should_be_editable_with_parent_issue_dates_set_to_independent
    with_settings :parent_issue_dates => 'independent' do
      issue = Issue.generate_with_child!
      user = User.find(1)
      %w(start_date due_date).each do |attribute|
        assert issue.safe_attribute?(attribute, user)
      end
    end
  end

  def test_parent_dates_should_not_be_updated_with_parent_issue_dates_set_to_independent
    with_settings :parent_issue_dates => 'independent' do
      parent = Issue.generate!(:start_date => '2015-07-01', :due_date => '2015-08-01')
      parent.generate_child!(:start_date => '2015-06-01', :due_date => '2015-09-01')
      parent.reload
      assert_equal Date.parse('2015-07-01'), parent.start_date
      assert_equal Date.parse('2015-08-01'), parent.due_date
    end
  end

  def test_reschuling_a_parent_should_not_reschedule_subtasks_with_parent_issue_dates_set_to_independent
    with_settings :parent_issue_dates => 'independent' do
      parent = Issue.generate!(:start_date => '2010-05-01', :due_date => '2010-05-20')
      c1 = parent.generate_child!(:start_date => '2010-05-12', :due_date => '2010-05-18')
      parent.reload.reschedule_on!(Date.parse('2010-06-01'))
      assert_equal Date.parse('2010-06-01'), parent.reload.start_date
      c1.reload
      assert_equal [Date.parse('2010-05-12'), Date.parse('2010-05-18')], [c1.start_date, c1.due_date]
    end
  end

  def test_parent_priority_should_be_editable_with_parent_issue_priority_set_to_independent
    with_settings :parent_issue_priority => 'independent' do
      issue = Issue.generate_with_child!
      user = User.find(1)
      assert issue.safe_attribute?('priority_id', user)
    end
  end

  def test_parent_priority_should_not_be_updated_with_parent_issue_priority_set_to_independent
    with_settings :parent_issue_priority => 'independent' do
      parent = Issue.generate!(:priority => IssuePriority.find_by_name('Normal'))
      child1 = parent.generate_child!(:priority => IssuePriority.find_by_name('High'))
      assert_equal 'Normal', parent.reload.priority.name
    end
  end

  def test_parent_done_ratio_should_be_editable_with_parent_issue_done_ratio_set_to_independent
    with_settings :parent_issue_done_ratio => 'independent' do
      issue = Issue.generate_with_child!
      user = User.find(1)
      assert issue.safe_attribute?('done_ratio', user)
    end
  end

  def test_parent_done_ratio_should_not_be_updated_with_parent_issue_done_ratio_set_to_independent
    with_settings :parent_issue_done_ratio => 'independent' do
      parent = Issue.generate!(:done_ratio => 0)
      child1 = parent.generate_child!(:done_ratio => 10)
      assert_equal 0, parent.reload.done_ratio
    end
  end

  def test_parent_total_estimated_hours_should_be_sum_of_visible_descendants
    parent = Issue.generate!
    parent.generate_child!(:estimated_hours => nil)
    assert_equal 0, parent.reload.total_estimated_hours
    parent.generate_child!(:estimated_hours => 5)
    assert_equal 5, parent.reload.total_estimated_hours
    parent.generate_child!(:estimated_hours => 7)
    assert_equal 12, parent.reload.total_estimated_hours

    parent.generate_child!(:estimated_hours => 9, :is_private => true)
    assert_equal 12, parent.reload.total_estimated_hours
  end

  def test_open_issue_with_closed_parent_should_not_validate
    parent = Issue.generate!(:status_id => 5)
    child = Issue.generate!

    child.parent_issue_id = parent.id
    assert !child.save
    assert_include I18n.t("activerecord.errors.messages.open_issue_with_closed_parent"), child.errors.full_messages
  end
end
