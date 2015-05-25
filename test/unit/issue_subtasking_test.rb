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

class IssueSubtaskingTest < ActiveSupport::TestCase
  fixtures :projects, :users, :roles, :members, :member_roles,
           :trackers, :projects_trackers,
           :issue_statuses, :issue_categories, :enumerations,
           :issues

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
      parent.generate_child!(                             :due_date => '2010-02-13')
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

  def test_parent_priority_should_be_the_highest_child_priority
    with_settings :parent_issue_priority => 'derived' do
      parent = Issue.generate!(:priority => IssuePriority.find_by_name('Normal'))
      # Create children
      child1 = parent.generate_child!(:priority => IssuePriority.find_by_name('High'))
      assert_equal 'High', parent.reload.priority.name
      child2 = child1.generate_child!(:priority => IssuePriority.find_by_name('Immediate'))
      assert_equal 'Immediate', child1.reload.priority.name
      assert_equal 'Immediate', parent.reload.priority.name
      child3 = parent.generate_child!(:priority => IssuePriority.find_by_name('Low'))
      assert_equal 'Immediate', parent.reload.priority.name
      # Destroy a child
      child1.destroy
      assert_equal 'Low', parent.reload.priority.name
      # Update a child
      child3.reload.priority = IssuePriority.find_by_name('Normal')
      child3.save!
      assert_equal 'Normal', parent.reload.priority.name
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
end
