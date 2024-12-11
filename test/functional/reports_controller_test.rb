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

class ReportsControllerTest < Redmine::ControllerTest
  def test_get_issue_report
    get(
      :issue_report,
      :params => {
        :id => 1
      }
    )
    assert_response :success
  end

  def test_issue_report_with_subprojects_issues
    project = Project.find(1)
    tracker = project.trackers.find_by(:name => 'Support request')
    project.trackers.delete(tracker)

    with_settings :display_subprojects_issues => '1' do
      get(
        :issue_report,
        :params => {
          :id => 1
        }
      )
      assert_response :success
      # Count subprojects issues
      assert_select 'table.list tbody :nth-child(1):first' do
        assert_select 'td', :text => 'Bug'
        assert_select ':nth-child(2)', :text => '5' # open
        assert_select ':nth-child(3)', :text => '3' # closed
        assert_select ':nth-child(4)', :text => '8' # total
      end
      assert_select 'table.issue-report td.name', :text => 'Support request', :count => 1
    end
  end

  def test_issue_report_without_subprojects_issues
    project = Project.find(1)
    tracker = project.trackers.find_by(:name => 'Support request')
    project.trackers.delete(tracker)

    with_settings :display_subprojects_issues => '0' do
      get(
        :issue_report,
        :params => {
          :id => 1
        }
      )
      assert_response :success
      # Do not count subprojects issues
      assert_select 'table.list tbody :nth-child(1):first' do
        assert_select 'td', :text => 'Bug'
        assert_select ':nth-child(2)', :text => '3' # open
        assert_select ':nth-child(3)', :text => '3' # closed
        assert_select ':nth-child(4)', :text => '6' # total
      end
      assert_select 'table.issue-report td.name', :text => 'Support request', :count => 0
    end
  end

  def test_get_issue_report_details
    %w(tracker version priority category assigned_to author subproject).each do |detail|
      get(
        :issue_report_details,
        :params => {
          :id => 1,
          :detail => detail
        }
      )
      assert_response :success
    end
  end

  def test_get_issue_report_details_by_tracker_should_show_only_statuses_used_by_the_project
    WorkflowTransition.delete_all
    WorkflowTransition.create(:role_id => 1, :tracker_id => 1, :old_status_id => 1, :new_status_id => 5)
    WorkflowTransition.create(:role_id => 1, :tracker_id => 1, :old_status_id => 1, :new_status_id => 4)
    WorkflowTransition.create(:role_id => 1, :tracker_id => 1, :old_status_id => 2, :new_status_id => 5)
    WorkflowTransition.create(:role_id => 1, :tracker_id => 2, :old_status_id => 1, :new_status_id => 6)
    WorkflowTransition.create(:role_id => 1, :tracker_id => 2, :old_status_id => 3, :new_status_id => 3)

    with_settings :display_subprojects_issues => '0' do
      get(:issue_report_details, :params => {:id => 1, :detail => 'tracker'})
    end
    assert_response :success
    assert_select 'table.list tbody :nth-child(1)' do
      assert_select 'td', :text => 'Bug'
      assert_select ':nth-child(2)', :text => '3' # status:1
      assert_select ':nth-child(3)', :text => '-' # status:2
      assert_select ':nth-child(4)', :text => '-' # status:4
      assert_select ':nth-child(5)', :text => '3' # status:5
      assert_select ':nth-child(6)', :text => '-' # status:6
      assert_select ':nth-child(7)', :text => '3' # open
      assert_select ':nth-child(8)', :text => '3' # closed
      assert_select ':nth-child(9)', :text => '6' # total
    end
  end

  def test_get_issue_report_details_by_tracker_with_subprojects_issues
    project = Project.find(1)
    tracker = project.trackers.find_by(:name => 'Support request')
    project.trackers.delete(tracker)

    with_settings :display_subprojects_issues => '1' do
      get(
        :issue_report_details,
        :params => {
          :id => 1,
          :detail => 'tracker'
        }
      )
      assert_response :success
      # Count subprojects issues
      assert_select 'table.list tbody :nth-child(1)' do
        assert_select 'td', :text => 'Bug'
        assert_select ':nth-child(2)', :text => '5' # status:1
        assert_select ':nth-child(3)', :text => '-' # status:2
        assert_select ':nth-child(4)', :text => '-' # status:3
        assert_select ':nth-child(5)', :text => '-' # status:4
        assert_select ':nth-child(6)', :text => '3' # status:5
        assert_select ':nth-child(7)', :text => '-' # status:6
        assert_select ':nth-child(8)', :text => '5' # open
        assert_select ':nth-child(9)', :text => '3' # closed
        assert_select ':nth-child(10)', :text => '8' # total
      end
      assert_select 'table.issue-report-detailed td.name', :text => 'Support request', :count => 1
    end
  end

  def test_get_issue_report_details_by_tracker_without_subprojects_issues
    project = Project.find(1)
    tracker = project.trackers.find_by(:name => 'Support request')
    project.trackers.delete(tracker)

    with_settings :display_subprojects_issues => '0' do
      get :issue_report_details, :params => {
        :id => 1,
        :detail => 'tracker'
      }

      assert_response :success
      # Do not count subprojects issues
      assert_select 'table.list tbody :nth-child(1)' do
        assert_select 'td', :text => 'Bug'
        assert_select ':nth-child(2)', :text => '3' # status:1
        assert_select ':nth-child(3)', :text => '-' # status:2
        assert_select ':nth-child(4)', :text => '-' # status:3
        assert_select ':nth-child(5)', :text => '-' # status:4
        assert_select ':nth-child(6)', :text => '3' # status:5
        assert_select ':nth-child(7)', :text => '-' # status:6
        assert_select ':nth-child(8)', :text => '3' # open
        assert_select ':nth-child(9)', :text => '3' # closed
        assert_select ':nth-child(10)', :text => '6' # total
      end
      assert_select 'table.issue-report td.name', :text => 'Support request', :count => 0
    end
  end

  def test_get_issue_report_details_by_tracker_should_show_issue_count
    Issue.delete_all
    Issue.generate!(:tracker_id => 1)
    Issue.generate!(:tracker_id => 1)
    Issue.generate!(:tracker_id => 1, :status_id => 5)
    Issue.generate!(:tracker_id => 2)

    get(
      :issue_report_details,
      :params => {
        :id => 1,
        :detail => 'tracker'
      }
    )
    assert_select 'table.list tbody :nth-child(1)' do
      assert_select 'td', :text => 'Bug'
      assert_select ':nth-child(2)', :text => '2' # status:1
      assert_select ':nth-child(3)', :text => '-' # status:2
      assert_select ':nth-child(8)', :text => '2' # open
      assert_select ':nth-child(9)', :text => '1' # closed
      assert_select ':nth-child(10)', :text => '3' # total
    end
    assert_select 'table.list tfoot :nth-child(1)' do
      assert_select 'td', :text => 'Total'
      assert_select ':nth-child(2)', :text => '3' # status:1
      assert_select ':nth-child(3)', :text => '0' # status:2
      assert_select ':nth-child(4)', :text => '0' # status:3
      assert_select ':nth-child(5)', :text => '0' # status:4
      assert_select ':nth-child(6)', :text => '1' # status:5
      assert_select ':nth-child(8)', :text => '3' # open
      assert_select ':nth-child(9)', :text => '1' # closed
      assert_select ':nth-child(10)', :text => '4' # total
    end
  end

  def test_get_issue_report_details_by_assignee_should_show_non_assigned_issue_count
    Issue.delete_all
    Issue.generate!
    Issue.generate!
    Issue.generate!(:status_id => 5)
    Issue.generate!(:assigned_to_id => 2)

    get(
      :issue_report_details,
      :params => {
        :id => 1,
        :detail => 'assigned_to'
      }
    )
    assert_select 'table.list tbody :last-child' do
      assert_select 'td', :text => "[#{I18n.t(:label_none)}]"
      assert_select ':nth-child(2)', :text => '2' # status:1
      assert_select ':nth-child(6)', :text => '1' # status:5
      assert_select ':nth-child(8)', :text => '2' # open
      assert_select ':nth-child(9)', :text => '1' # closed
      assert_select ':nth-child(10)', :text => '3' # total
    end
  end

  def test_get_issue_report_details_with_an_invalid_detail
    get(
      :issue_report_details,
      :params => {
        :id => 1,
        :detail => 'invalid'
      }
    )
    assert_response :not_found
  end

  def test_issue_report_details_should_csv_export
    %w(tracker version priority category assigned_to author subproject).each do |detail|
      get(
        :issue_report_details,
        params: {
          id: 1,
          detail: detail,
          format: 'csv'
        }
      )
      assert_response :success
      assert_equal 'text/csv; header=present', response.media_type
    end
  end

  def test_issue_report_details_with_tracker_detail_should_csv_export
    project = Project.find(1)
    tracker = project.trackers.find_by(:name => 'Support request')
    project.trackers.delete(tracker)

    with_settings :display_subprojects_issues => '1' do
      get(
        :issue_report_details,
        params: {
          id: 1,
          detail: 'tracker',
          format: 'csv'
        }
      )
      assert_response :success

      assert_equal 'text/csv; header=present', response.media_type
      lines = response.body.chomp.split("\n")
      # Number of lines
      rows = Project.find(1).rolled_up_trackers(true).visible
      assert_equal rows.size + 1, lines.size
      # Header
      assert_equal '"",New,Assigned,Resolved,Feedback,Closed,Rejected,open,closed,Total', lines.first
      # Details
      to_test = [
        'Bug,5,0,0,0,3,0,5,3,8',
        'Feature request,0,1,0,0,0,0,1,0,1',
        'Support request,0,0,0,0,0,0,0,0,0'
      ]
      to_test.each do |expected|
        assert_includes lines, expected
      end
    end
  end

  def test_issue_report_details_with_assigned_to_detail_should_csv_export
    Issue.delete_all
    Issue.generate!
    Issue.generate!
    Issue.generate!(:status_id => 5)
    Issue.generate!(:assigned_to_id => 2)

    with_settings :issue_group_assignment => '1' do
      get(
        :issue_report_details,
        params: {
          id: 1,
          detail: 'assigned_to',
          format: 'csv'
        }
      )
      assert_response :success

      assert_equal 'text/csv; header=present', response.media_type
      lines = response.body.chomp.split("\n")
      # Number of lines
      rows = Project.find(1).principals.sorted + [I18n.t(:label_none)]
      assert_equal rows.size + 1, lines.size
      # Header
      assert_equal '"",New,Assigned,Resolved,Feedback,Closed,Rejected,open,closed,Total', lines.first
      # Details
      to_test = [
        'Dave Lopper,0,0,0,0,0,0,0,0,0',
        'John Smith,1,0,0,0,0,0,1,0,1',
        '[none] ,2,0,0,0,1,0,2,1,3'
      ]
      to_test.each do |expected|
        assert_includes lines, expected
      end
    end
  end
end
