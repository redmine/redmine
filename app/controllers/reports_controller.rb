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

class ReportsController < ApplicationController
  menu_item :issues
  before_action :find_project, :authorize, :find_issue_statuses

  include ReportsHelper
  def issue_report
    with_subprojects = Setting.display_subprojects_issues?
    @trackers = @project.rolled_up_trackers(with_subprojects).visible
    @versions = @project.shared_versions.sorted + [Version.new(:name => "[#{l(:label_none)}]")]
    @priorities = IssuePriority.all.reverse
    @categories = @project.issue_categories + [IssueCategory.new(:name => "[#{l(:label_none)}]")]
    @assignees = (Setting.issue_group_assignment? ? @project.principals : @project.users).sorted + [User.new(:firstname => "[#{l(:label_none)}]")]
    @authors = @project.users.sorted
    @subprojects = @project.descendants.visible
    @issues_by_tracker = Issue.by_tracker(@project, with_subprojects)
    @issues_by_version = Issue.by_version(@project, with_subprojects)
    @issues_by_priority = Issue.by_priority(@project, with_subprojects)
    @issues_by_category = Issue.by_category(@project, with_subprojects)
    @issues_by_assigned_to = Issue.by_assigned_to(@project, with_subprojects)
    @issues_by_author = Issue.by_author(@project, with_subprojects)
    @issues_by_subproject = Issue.by_subproject(@project) || []

    render :template => "reports/issue_report"
  end

  def issue_report_details
    with_subprojects = Setting.display_subprojects_issues?
    case params[:detail]
    when "tracker"
      @field = "tracker_id"
      @rows = @project.rolled_up_trackers(with_subprojects).visible
      @data = Issue.by_tracker(@project, with_subprojects)
      @report_title = l(:field_tracker)
    when "version"
      @field = "fixed_version_id"
      @rows = @project.shared_versions.sorted + [Version.new(:name => "[#{l(:label_none)}]")]
      @data = Issue.by_version(@project, with_subprojects)
      @report_title = l(:field_version)
    when "priority"
      @field = "priority_id"
      @rows = IssuePriority.all.reverse
      @data = Issue.by_priority(@project, with_subprojects)
      @report_title = l(:field_priority)
    when "category"
      @field = "category_id"
      @rows = @project.issue_categories + [IssueCategory.new(:name => "[#{l(:label_none)}]")]
      @data = Issue.by_category(@project, with_subprojects)
      @report_title = l(:field_category)
    when "assigned_to"
      @field = "assigned_to_id"
      @rows = (Setting.issue_group_assignment? ? @project.principals : @project.users).sorted + [User.new(:firstname => "[#{l(:label_none)}]")]
      @data = Issue.by_assigned_to(@project, with_subprojects)
      @report_title = l(:field_assigned_to)
    when "author"
      @field = "author_id"
      @rows = @project.users.sorted
      @data = Issue.by_author(@project, with_subprojects)
      @report_title = l(:field_author)
    when "subproject"
      @field = "project_id"
      @rows = @project.descendants.visible
      @data = Issue.by_subproject(@project) || []
      @report_title = l(:field_subproject)
    else
      render_404
    end
    respond_to do |format|
      format.html
      format.csv do
        send_data(issue_report_details_to_csv(@field, @statuses, @rows, @data),
                  :type => 'text/csv; header=present',
                  :filename => "report-#{params[:detail]}.csv")
      end
    end
  end

  private

  def find_issue_statuses
    @statuses = @project.rolled_up_statuses.sorted.to_a
  end
end
