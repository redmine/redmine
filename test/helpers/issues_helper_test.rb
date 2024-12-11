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

class IssuesHelperTest < Redmine::HelperTest
  include IssuesHelper
  include CustomFieldsHelper
  include ERB::Util

  def test_issue_heading
    assert_equal "Bug #1", issue_heading(Issue.find(1))
  end

  def test_issues_destroy_confirmation_message_with_one_root_issue
    assert_equal l(:text_issues_destroy_confirmation),
                 issues_destroy_confirmation_message(Issue.find(1))
  end

  def test_issues_destroy_confirmation_message_with_an_arrayt_of_root_issues
    assert_equal l(:text_issues_destroy_confirmation),
                 issues_destroy_confirmation_message(Issue.find([1, 2]))
  end

  def test_issues_destroy_confirmation_message_with_one_parent_issue
    Issue.find(2).update! :parent_issue_id => 1
    assert_equal l(:text_issues_destroy_confirmation) + "\n" +
                   l(:text_issues_destroy_descendants_confirmation, :count => 1),
                 issues_destroy_confirmation_message(Issue.find(1))
  end

  def test_issues_destroy_confirmation_message_with_one_parent_issue_and_its_child
    Issue.find(2).update! :parent_issue_id => 1
    assert_equal l(:text_issues_destroy_confirmation),
                 issues_destroy_confirmation_message(Issue.find([1, 2]))
  end

  def test_issues_destroy_confirmation_message_with_issues_that_share_descendants
    root = Issue.generate!
    child = Issue.generate!(:parent_issue_id => root.id)
    Issue.generate!(:parent_issue_id => child.id)

    assert_equal l(:text_issues_destroy_confirmation) + "\n" +
                   l(:text_issues_destroy_descendants_confirmation, :count => 1),
                 issues_destroy_confirmation_message([root.reload, child.reload])
  end

  test 'show_detail with no_html should show a changing attribute' do
    detail = JournalDetail.new(:property => 'attr', :old_value => '40',
                               :value => '100', :prop_key => 'done_ratio')
    assert_equal "% Done changed from 40 to 100", show_detail(detail, true)
  end

  test 'show_detail with no_html should show a new attribute' do
    detail = JournalDetail.new(:property => 'attr', :old_value => nil,
                               :value => '100', :prop_key => 'done_ratio')
    assert_equal "% Done set to 100", show_detail(detail, true)
  end

  test 'show_detail with no_html should show a deleted attribute' do
    detail = JournalDetail.new(:property => 'attr', :old_value => '50',
                               :value => nil, :prop_key => 'done_ratio')
    assert_equal "% Done deleted (50)", show_detail(detail, true)
  end

  test 'show_detail with html should show a changing attribute with HTML highlights' do
    detail = JournalDetail.new(:property => 'attr', :old_value => '40',
                               :value => '100', :prop_key => 'done_ratio')
    html = show_detail(detail, false)
    assert_include '<strong>% Done</strong>', html
    assert_include '<i>40</i>', html
    assert_include '<i>100</i>', html
  end

  test 'show_detail with html should show a new attribute with HTML highlights' do
    detail = JournalDetail.new(:property => 'attr', :old_value => nil,
                               :value => '100', :prop_key => 'done_ratio')
    html = show_detail(detail, false)
    assert_include '<strong>% Done</strong>', html
    assert_include '<i>100</i>', html
  end

  test 'show_detail with html should show a deleted attribute with HTML highlights' do
    detail = JournalDetail.new(:property => 'attr', :old_value => '50',
                               :value => nil, :prop_key => 'done_ratio')
    html = show_detail(detail, false)
    assert_include '<strong>% Done</strong>', html
    assert_include '<del><i>50</i></del>', html
  end

  test 'show_detail with a start_date attribute should format the dates' do
    detail =
      JournalDetail.new(
        :property  => 'attr',
        :old_value => '2010-01-01',
        :value     => '2010-01-31',
        :prop_key  => 'start_date'
      )
    with_settings :date_format => '%m/%d/%Y' do
      assert_match "01/31/2010", show_detail(detail, true)
      assert_match "01/01/2010", show_detail(detail, true)
    end
  end

  test 'show_detail with a due_date attribute should format the dates' do
    detail =
      JournalDetail.new(
        :property  => 'attr',
        :old_value => '2010-01-01',
        :value     => '2010-01-31',
        :prop_key  => 'due_date'
      )
    with_settings :date_format => '%m/%d/%Y' do
      assert_match "01/31/2010", show_detail(detail, true)
      assert_match "01/01/2010", show_detail(detail, true)
    end
  end

  test 'show_detail should show old and new values with a project attribute' do
    User.current = User.find(2)
    detail = JournalDetail.new(:property => 'attr', :prop_key => 'project_id',
                               :old_value => 1, :value => 2)
    assert_match 'eCookbook', show_detail(detail, true)
    assert_match 'OnlineStore', show_detail(detail, true)
  end

  test 'show_detail with a project attribute should show project ID if project is not visible' do
    detail = JournalDetail.new(:property => 'attr', :prop_key => 'project_id',
                               :old_value => 1, :value => 2)
    assert_match 'eCookbook', show_detail(detail, true)
    assert_match '2', show_detail(detail, true)
  end

  test 'show_detail should show old and new values with a issue status attribute' do
    detail = JournalDetail.new(:property => 'attr', :prop_key => 'status_id',
                               :old_value => 1, :value => 2)
    assert_match 'New', show_detail(detail, true)
    assert_match 'Assigned', show_detail(detail, true)
  end

  test 'show_detail should show old and new values with a tracker attribute' do
    detail = JournalDetail.new(:property => 'attr', :prop_key => 'tracker_id',
                               :old_value => 1, :value => 2)
    assert_match 'Bug', show_detail(detail, true)
    assert_match 'Feature request', show_detail(detail, true)
  end

  test 'show_detail should show old and new values with a assigned to attribute' do
    detail = JournalDetail.new(:property => 'attr', :prop_key => 'assigned_to_id',
                               :old_value => 1, :value => 2)
    assert_match 'Redmine Admin', show_detail(detail, true)
    assert_match 'John Smith', show_detail(detail, true)
  end

  test 'show_detail should show old and new values with a priority attribute' do
    detail = JournalDetail.new(:property => 'attr', :prop_key => 'priority_id',
                               :old_value => 4, :value => 5)
    assert_match 'Low', show_detail(detail, true)
    assert_match 'Normal', show_detail(detail, true)
  end

  test 'show_detail should show old and new values with a category attribute' do
    detail = JournalDetail.new(:property => 'attr', :prop_key => 'category_id',
                               :old_value => 1, :value => 2)
    assert_match 'Printing', show_detail(detail, true)
    assert_match 'Recipes', show_detail(detail, true)
  end

  test 'show_detail should show old and new values with a fixed version attribute' do
    detail = JournalDetail.new(:property => 'attr', :prop_key => 'fixed_version_id',
                               :old_value => 1, :value => 2)
    assert_match '0.1', show_detail(detail, true)
    assert_match '1.0', show_detail(detail, true)
  end

  test 'show_detail should show old and new values with a estimated hours attribute' do
    detail = JournalDetail.new(:property => 'attr', :prop_key => 'estimated_hours',
                               :old_value => '5', :value => '6.3')
    assert_match '5:00', show_detail(detail, true)
    assert_match '6:18', show_detail(detail, true)
  end

  test 'show_detail should not show values with a description attribute' do
    detail = JournalDetail.new(:property => 'attr', :prop_key => 'description',
                               :old_value => 'Foo', :value => 'Bar')
    assert_equal 'Description updated', show_detail(detail, true)
  end

  test 'show_detail should show old and new values with a custom field' do
    detail = JournalDetail.new(:property => 'cf', :prop_key => '1',
                               :old_value => 'MySQL', :value => 'PostgreSQL')
    assert_equal 'Database changed from MySQL to PostgreSQL', show_detail(detail, true)
  end

  test 'show_detail should not show values with a long text custom field' do
    field = IssueCustomField.create!(:name => "Long field", :field_format => 'text')
    detail = JournalDetail.new(:property => 'cf', :prop_key => field.id,
                               :old_value => 'Foo', :value => 'Bar')
    assert_equal 'Long field updated', show_detail(detail, true)
  end

  test 'show_detail should show added file' do
    detail = JournalDetail.new(:property => 'attachment', :prop_key => '1',
                               :old_value => nil, :value => 'error281.txt')
    assert_match 'error281.txt', show_detail(detail, true)
  end

  test 'show_detail should show removed file' do
    detail = JournalDetail.new(:property => 'attachment', :prop_key => '1',
                               :old_value => 'error281.txt', :value => nil)
    assert_match 'error281.txt', show_detail(detail, true)
  end

  def test_show_detail_relation_added
    detail = JournalDetail.new(:property => 'relation',
                               :prop_key => 'precedes',
                               :value    => 1)
    assert_equal "Precedes Bug #1: Cannot print recipes added", show_detail(detail, true)
    str = link_to("Bug #1", "/issues/1", :class => Issue.find(1).css_classes)
    assert_equal "<strong>Precedes</strong> <i>#{str}: Cannot print recipes</i> added",
                 show_detail(detail, false)
  end

  def test_show_detail_relation_added_with_inexistant_issue
    inexistant_issue_number = 9999
    assert_nil  Issue.find_by_id(inexistant_issue_number)
    detail = JournalDetail.new(:property => 'relation',
                               :prop_key => 'precedes',
                               :value    => inexistant_issue_number)
    assert_equal "Precedes Issue ##{inexistant_issue_number} added", show_detail(detail, true)
    assert_equal "<strong>Precedes</strong> <i>Issue ##{inexistant_issue_number}</i> added", show_detail(detail, false)
  end

  def test_show_detail_relation_added_should_not_disclose_issue_that_is_not_visible
    issue = Issue.generate!(:is_private => true)
    detail = JournalDetail.new(:property => 'relation',
                               :prop_key => 'precedes',
                               :value    => issue.id)

    assert_equal "Precedes Issue ##{issue.id} added", show_detail(detail, true)
    assert_equal "<strong>Precedes</strong> <i>Issue ##{issue.id}</i> added", show_detail(detail, false)
  end

  def test_show_detail_relation_deleted
    detail = JournalDetail.new(:property  => 'relation',
                               :prop_key  => 'precedes',
                               :old_value => 1)
    assert_equal "Precedes deleted (Bug #1: Cannot print recipes)", show_detail(detail, true)
    str = link_to("Bug #1",
                  "/issues/1",
                  :class => Issue.find(1).css_classes)
    assert_equal "<strong>Precedes</strong> deleted (<i>#{str}: Cannot print recipes</i>)",
                 show_detail(detail, false)
  end

  def test_show_detail_relation_deleted_with_inexistant_issue
    inexistant_issue_number = 9999
    assert_nil  Issue.find_by_id(inexistant_issue_number)
    detail = JournalDetail.new(:property  => 'relation',
                               :prop_key  => 'precedes',
                               :old_value => inexistant_issue_number)
    assert_equal "Precedes deleted (Issue #9999)", show_detail(detail, true)
    assert_equal "<strong>Precedes</strong> deleted (<i>Issue #9999</i>)", show_detail(detail, false)
  end

  def test_show_detail_relation_deleted_should_not_disclose_issue_that_is_not_visible
    issue = Issue.generate!(:is_private => true)
    detail = JournalDetail.new(:property => 'relation',
                               :prop_key => 'precedes',
                               :old_value    => issue.id)

    assert_equal "Precedes deleted (Issue ##{issue.id})", show_detail(detail, true)
    assert_equal "<strong>Precedes</strong> deleted (<i>Issue ##{issue.id}</i>)", show_detail(detail, false)
  end

  def test_details_to_strings_with_multiple_values_removed_from_custom_field
    field = IssueCustomField.generate!(:name => 'User', :field_format => 'user', :multiple => true)
    details = []
    details << JournalDetail.new(:property => 'cf', :prop_key => field.id.to_s, :old_value => '1', :value => nil)
    details << JournalDetail.new(:property => 'cf', :prop_key => field.id.to_s, :old_value => '3', :value => nil)

    assert_equal ["User deleted (Dave Lopper, Redmine Admin)"], details_to_strings(details, true)
    assert_equal ["<strong>User</strong> deleted (<del><i>Dave Lopper, Redmine Admin</i></del>)"], details_to_strings(details, false)
  end

  def test_details_to_strings_with_multiple_values_added_to_custom_field
    field = IssueCustomField.generate!(:name => 'User', :field_format => 'user', :multiple => true)
    details = []
    details << JournalDetail.new(:property => 'cf', :prop_key => field.id.to_s, :old_value => nil, :value => '1')
    details << JournalDetail.new(:property => 'cf', :prop_key => field.id.to_s, :old_value => nil, :value => '3')

    assert_equal ["User Dave Lopper, Redmine Admin added"], details_to_strings(details, true)
    assert_equal ["<strong>User</strong> <i>Dave Lopper, Redmine Admin</i> added"], details_to_strings(details, false)
  end

  def test_details_to_strings_with_multiple_values_added_and_removed_from_custom_field
    field = IssueCustomField.generate!(:name => 'User', :field_format => 'user', :multiple => true)
    details = []
    details << JournalDetail.new(:property => 'cf', :prop_key => field.id.to_s, :old_value => nil, :value => '1')
    details << JournalDetail.new(:property => 'cf', :prop_key => field.id.to_s, :old_value => '2', :value => nil)
    details << JournalDetail.new(:property => 'cf', :prop_key => field.id.to_s, :old_value => '3', :value => nil)

    assert_equal(
      [
        "User Redmine Admin added",
        "User deleted (Dave Lopper, John Smith)"
      ],
      details_to_strings(details, true)
    )
    assert_equal(
      [
        "<strong>User</strong> <i>Redmine Admin</i> added",
        "<strong>User</strong> deleted (<del><i>Dave Lopper, John Smith</i></del>)"
      ],
      details_to_strings(details, false)
    )
  end

  def test_find_name_by_reflection_should_return_nil_for_missing_record
    assert_nil find_name_by_reflection('status', 99)
  end

  def test_issue_due_date_details
    travel_to Time.parse('2019-06-01 23:00:00 UTC') do
      User.current = User.first
      User.current.pref.update_attribute :time_zone, 'UTC'
      issue = Issue.generate!

      # due date is not set
      assert_nil issue_due_date_details(issue)

      # due date is set
      issue.due_date = User.current.today + 5
      issue.save!
      assert_equal '06/06/2019 (Due in 5 days)', issue_due_date_details(issue)

      # Don't show "Due in X days" if the issue is closed
      issue.status = IssueStatus.find_by_is_closed(true)
      issue.save!
      assert_equal '06/06/2019', issue_due_date_details(issue)
    end
  end

  def test_url_for_new_subtask
    issue = Issue.find(1)
    params = {:issue => {:parent_issue_id => issue.id, :tracker_id => issue.tracker.id}}
    assert_equal new_project_issue_path(issue.project, params),
                 url_for_new_subtask(issue)
  end

  def test_issue_spent_hours_details_should_link_to_project_time_entries_depending_on_cross_project_setting
    %w(descendants).each do |setting|
      with_settings :cross_project_subtasks => setting do
        TimeEntry.generate!(:issue => Issue.generate!(:parent_issue_id => 1), :hours => 3)
        TimeEntry.generate!(:issue => Issue.generate!(:parent_issue_id => 1), :hours => 4)

        assert_match "href=\"/projects/ecookbook/time_entries?issue_id=~1\"", issue_spent_hours_details(Issue.find(1))
      end
    end
  end

  def test_issue_spent_hours_details_should_link_to_global_time_entries_depending_on_cross_project_setting
    %w(system tree hierarchy).each do |setting|
      with_settings :cross_project_subtasks => setting do
        TimeEntry.generate!(:issue => Issue.generate!(:parent_issue_id => 1), :hours => 3)
        TimeEntry.generate!(:issue => Issue.generate!(:parent_issue_id => 1), :hours => 4)

        assert_match "href=\"/time_entries?issue_id=~1\"", issue_spent_hours_details(Issue.find(1))
      end
    end
  end

  def test_render_issues_stats
    html = render_issues_stats(1, 1, {:issue_id => '15,16'})

    assert_include '<a href="/issues?issue_id=15%2C16&amp;set_filter=true&amp;status_id=%2A">2</a>', html
    assert_include '<a href="/issues?issue_id=15%2C16&amp;set_filter=true&amp;status_id=o">1 open</a>', html
    assert_include '<a href="/issues?issue_id=15%2C16&amp;set_filter=true&amp;status_id=c">1 closed</a>', html
  end

  def test_render_issue_relations
    issue = Issue.generate!(:status_id => 1)
    closed_issue = Issue.generate!(:status_id => 5)
    relation = IssueRelation.create!(:issue_from => closed_issue,
                                     :issue_to => issue,
                                     :relation_type => IssueRelation::TYPE_FOLLOWS)

    html = render_issue_relations(issue, [relation])
    assert_include(
      "<tr id=\"relation-#{relation.id}\"" \
      " class=\"issue hascontextmenu issue" \
      " tracker-#{closed_issue.tracker_id}" \
      " status-#{closed_issue.status_id}" \
      " priority-#{closed_issue.priority_id} priority-default" \
      " closed rel-follows\">",
      html
    )

    html = render_issue_relations(closed_issue, [relation])
    assert_include(
      "<tr id=\"relation-#{relation.id}\"" \
      " class=\"issue hascontextmenu issue" \
      " tracker-#{issue.tracker_id}" \
      " status-#{issue.status_id}" \
      " priority-#{issue.priority_id} priority-default" \
      " rel-precedes\">",
      html
    )
  end

  def test_render_descendants_stats
    parent = Issue.generate!(:status_id => 1)
    child = Issue.generate!(:parent_issue_id => parent.id, :status_id => 1)
    Issue.generate!(:parent_issue_id => child.id, :status_id => 5)
    parent.reload
    html = render_descendants_stats(parent)

    assert_include "<a href=\"/issues?parent_id=~#{parent.id}&amp;set_filter=true&amp;status_id=%2A\">2</a>", html
    assert_include "<a href=\"/issues?parent_id=~#{parent.id}&amp;set_filter=true&amp;status_id=o\">1 open</a>", html
    assert_include "<a href=\"/issues?parent_id=~#{parent.id}&amp;set_filter=true&amp;status_id=c\">1 closed</a>", html
  end

  def test_render_relations_stats
    issue = Issue.generate!(:status_id => 1)
    relations = []
    open_issue = Issue.generate!(:status_id => 1)
    relations << IssueRelation.create!(:issue_from => open_issue,
                                       :issue_to => issue,
                                       :relation_type => IssueRelation::TYPE_RELATES)
    closed_issue = Issue.generate!(:status_id => 5)
    relations << IssueRelation.create!(:issue_from => closed_issue,
                                       :issue_to => issue,
                                       :relation_type => IssueRelation::TYPE_FOLLOWS)
    html = render_relations_stats(issue, relations)

    assert_include "<a href=\"/issues?issue_id=#{open_issue.id}%2C#{closed_issue.id}&amp;set_filter=true&amp;status_id=%2A\">2</a></span>", html
    assert_include "<a href=\"/issues?issue_id=#{open_issue.id}%2C#{closed_issue.id}&amp;set_filter=true&amp;status_id=o\">1 open</a>", html
    assert_include "<a href=\"/issues?issue_id=#{open_issue.id}%2C#{closed_issue.id}&amp;set_filter=true&amp;status_id=c\">1 closed</a>", html
  end
end
