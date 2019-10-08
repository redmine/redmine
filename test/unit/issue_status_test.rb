# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2019  Jean-Philippe Lang
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

class IssueStatusTest < ActiveSupport::TestCase
  fixtures :projects, :users, :members, :member_roles, :roles,
           :groups_users,
           :trackers, :projects_trackers,
           :enabled_modules,
           :versions,
           :issue_statuses, :issue_categories, :issue_relations, :workflows,
           :enumerations,
           :issues, :journals, :journal_details,
           :custom_fields, :custom_fields_projects, :custom_fields_trackers, :custom_values

  def setup
    User.current = nil
  end

  def test_create
    status = IssueStatus.new :name => "Assigned"
    assert !status.save
    # status name uniqueness
    assert_equal 1, status.errors.count

    status.name = "Test Status"
    assert status.save
  end

  def test_destroy
    status = IssueStatus.find(3)
    assert_difference 'IssueStatus.count', -1 do
      assert status.destroy
    end
    assert_nil WorkflowTransition.where(:old_status_id => status.id).first
    assert_nil WorkflowTransition.where(:new_status_id => status.id).first
  end

  def test_destroy_status_in_use
    # Status assigned to an Issue
    status = Issue.find(1).status
    assert_raise(RuntimeError, "Cannot delete status") { status.destroy }
  end

  def test_new_statuses_allowed_to
    WorkflowTransition.delete_all
    WorkflowTransition.create!(:role_id => 1, :tracker_id => 1,
                               :old_status_id => 1, :new_status_id => 2,
                               :author => false, :assignee => false)
    WorkflowTransition.create!(:role_id => 1, :tracker_id => 1,
                               :old_status_id => 1, :new_status_id => 3,
                               :author => true, :assignee => false)
    WorkflowTransition.create!(:role_id => 1, :tracker_id => 1,
                               :old_status_id => 1, :new_status_id => 4,
                               :author => false, :assignee => true)
    WorkflowTransition.create!(:role_id => 1, :tracker_id => 1,
                               :old_status_id => 1, :new_status_id => 5,
                               :author => true, :assignee => true)
    status = IssueStatus.find(1)
    role = Role.find(1)
    tracker = Tracker.find(1)

    assert_equal [2], status.new_statuses_allowed_to([role], tracker, false, false).map(&:id)
    assert_equal [2], status.find_new_statuses_allowed_to([role], tracker, false, false).map(&:id)

    assert_equal [2, 3, 5], status.new_statuses_allowed_to([role], tracker, true, false).map(&:id)
    assert_equal [2, 3, 5], status.find_new_statuses_allowed_to([role], tracker, true, false).map(&:id)

    assert_equal [2, 4, 5], status.new_statuses_allowed_to([role], tracker, false, true).map(&:id)
    assert_equal [2, 4, 5], status.find_new_statuses_allowed_to([role], tracker, false, true).map(&:id)

    assert_equal [2, 3, 4, 5], status.new_statuses_allowed_to([role], tracker, true, true).map(&:id)
    assert_equal [2, 3, 4, 5], status.find_new_statuses_allowed_to([role], tracker, true, true).map(&:id)
  end

  def test_update_done_ratios_with_issue_done_ratio_set_to_issue_field_should_change_nothing
    IssueStatus.find(1).update_attribute(:default_done_ratio, 50)

    with_settings :issue_done_ratio => 'issue_field' do
      IssueStatus.update_issue_done_ratios
      assert_equal 0, Issue.where(:done_ratio => 50).count
    end
  end

  def test_update_done_ratios_with_issue_done_ratio_set_to_issue_status_should_update_issues
    IssueStatus.find(1).update_attribute(:default_done_ratio, 50)
    with_settings :issue_done_ratio => 'issue_status' do
      IssueStatus.update_issue_done_ratios
      issues = Issue.where(:status_id => 1)
      assert_equal [50], issues.map {|issue| issue.read_attribute(:done_ratio)}.uniq
    end
  end

  def test_sorted_scope
    assert_equal IssueStatus.all.sort, IssueStatus.sorted.to_a
  end

  def test_named_scope
    status = IssueStatus.named("resolved").first
    assert_not_nil status
    assert_equal "Resolved", status.name
  end

  def test_setting_status_as_closed_should_set_closed_on_for_issues_without_status_journal
    issue = Issue.generate!(:status_id => 1, :created_on => 2.days.ago)
    assert_nil issue.closed_on

    issue.status.update! :is_closed => true

    issue.reload
    assert issue.closed?
    assert_equal issue.created_on, issue.closed_on
  end

  def test_setting_status_as_closed_should_set_closed_on_for_issues_with_status_journal
    issue = Issue.generate!(:status_id => 1, :created_on => 2.days.ago)
    issue.init_journal(User.find(1))
    issue.status_id = 2
    issue.save!

    issue.status.update! :is_closed => true

    issue.reload
    assert issue.closed?
    assert_equal issue.journals.first.created_on, issue.closed_on
  end

  def test_setting_status_as_closed_should_not_set_closed_on_for_issues_with_other_status
    issue = Issue.generate!(:status_id => 2)

    IssueStatus.find(1).update! :is_closed => true

    issue.reload
    assert !issue.closed?
    assert_nil issue.closed_on
  end
end
