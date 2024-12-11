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

require_relative '../../../../test_helper'

class Redmine::Helpers::GanttHelperTest < Redmine::HelperTest
  include ProjectsHelper
  include IssuesHelper
  include QueriesHelper
  include AvatarsHelper

  include ERB::Util

  def setup
    setup_with_controller
    User.current = User.find(1)
  end

  def today
    @today ||= Date.today
  end
  private :today

  def gantt_start
    @gantt.date_from
  end
  private :gantt_start

  def gantt_end
    @gantt.date_to
  end
  private :gantt_end

  # Creates a Gantt chart for a 4 week span
  def create_gantt(project=Project.generate!, options={})
    @project = project
    @gantt = Redmine::Helpers::Gantt.new(options)
    @gantt.project = @project
    @gantt.query = IssueQuery.new(:project => @project, :name => 'Gantt')
    @gantt.view = self
    @gantt.instance_variable_set(:@date_from, options[:date_from] || (today - 14))
    @gantt.instance_variable_set(:@date_to, options[:date_to] || (today + 14))
  end
  private :create_gantt

  test "#number_of_rows with one project should return the number of rows just for that project" do
    p1, p2 = Project.generate!, Project.generate!
    i1, i2 = Issue.generate!(:project => p1), Issue.generate!(:project => p2)
    create_gantt(p1)
    assert_equal 2, @gantt.number_of_rows
  end

  test "#number_of_rows with no project should return the total number of rows for all the projects, recursively" do
    p1, p2 = Project.generate!, Project.generate!
    create_gantt(nil)
    # fix the return value of #number_of_rows_on_project() to an arbitrary value
    # so that we really only test #number_of_rows
    @gantt.stubs(:number_of_rows_on_project).returns(7)
    # also fix #projects because we want to test #number_of_rows in isolation
    @gantt.stubs(:projects).returns(Project.all)
    # actual test
    assert_equal Project.count*7, @gantt.number_of_rows
  end

  test "#number_of_rows should not exceed max_rows option" do
    p = Project.generate!
    5.times do
      Issue.generate!(:project => p)
    end
    create_gantt(p)
    @gantt.render
    assert_equal 6, @gantt.number_of_rows
    assert !@gantt.truncated
    create_gantt(p, :max_rows => 3)
    @gantt.render
    assert_equal 3, @gantt.number_of_rows
    assert @gantt.truncated
  end

  test "#number_of_rows_on_project should count 0 for an empty the project" do
    create_gantt
    assert_equal 0, @gantt.number_of_rows_on_project(@project)
  end

  test "#number_of_rows_on_project should count the number of issues without a version" do
    create_gantt
    @project.issues << Issue.generate!(:project => @project, :fixed_version => nil)
    assert_equal 2, @gantt.number_of_rows_on_project(@project)
  end

  test "#number_of_rows_on_project should count the number of issues on versions, including cross-project" do
    create_gantt
    version = Version.generate!
    @project.versions << version
    @project.issues << Issue.generate!(:project => @project, :fixed_version => version)
    assert_equal 3, @gantt.number_of_rows_on_project(@project)
  end

  def setup_subjects
    create_gantt
    @project.enabled_module_names = [:issue_tracking]
    @tracker = Tracker.generate!
    @project.trackers << @tracker
    @version = Version.generate!(:effective_date => (today + 7), :sharing => 'none')
    @project.versions << @version
    @issue = Issue.generate!(:fixed_version => @version,
                               :subject => "gantt#line_for_project",
                               :tracker => @tracker,
                               :project => @project,
                               :done_ratio => 30,
                               :start_date => (today - 1),
                               :due_date => (today + 7))
    @project.issues << @issue
  end
  private :setup_subjects

  # TODO: more of an integration test
  test "#subjects project should be rendered" do
    setup_subjects
    @output_buffer = @gantt.subjects
    assert_select "div.project-name a", /#{@project.name}/
    assert_select 'div.project-name[style*="left:4px"]'
  end

  test "#subjects version should be rendered" do
    setup_subjects
    @output_buffer = @gantt.subjects
    assert_select "div.version-name a", /#{@version.name}/
    assert_select 'div.version-name[style*="left:24px"]'
  end

  test "#subjects version without assigned issues should not be rendered" do
    setup_subjects
    @version = Version.generate!(:effective_date => (today + 14),
                                       :sharing => 'none',
                                       :name => 'empty_version')
    @project.versions << @version
    @output_buffer = @gantt.subjects
    assert_select "div.version-name a", :text => /#{@version.name}/, :count => 0
  end

  test "#subjects issue should be rendered" do
    setup_subjects
    @output_buffer = @gantt.subjects
    assert_select "div.issue-subject", /#{@issue.subject}/
    # subject 62px: 44px + 18px(collapse/expand icon's width)
    assert_select 'div.issue-subject[style*="left:62px"]'
  end

  test "#subjects issue assigned to a shared version of another project should be rendered" do
    setup_subjects
    p = Project.generate!
    p.enabled_module_names = [:issue_tracking]
    @shared_version = Version.generate!(:sharing => 'system')
    p.versions << @shared_version
    # Reassign the issue to a shared version of another project
    @issue = Issue.generate!(:fixed_version => @shared_version,
                                   :subject => "gantt#assigned_to_shared_version",
                                   :tracker => @tracker,
                                   :project => @project,
                                   :done_ratio => 30,
                                   :start_date => (today - 1),
                                   :due_date => (today + 7))
    @project.issues << @issue
    @output_buffer = @gantt.subjects
    assert_select "div.issue-subject", /#{@issue.subject}/
  end

  test "#subjects issue with subtasks should indent subtasks" do
    setup_subjects
    attrs = {:project => @project, :tracker => @tracker, :fixed_version => @version}
    @child1 = Issue.generate!(
                       attrs.merge(:subject => 'child1',
                                   :parent_issue_id => @issue.id,
                                   :start_date => (today - 1),
                                   :due_date => (today + 2))
                     )
    @child2 = Issue.generate!(
                       attrs.merge(:subject => 'child2',
                                   :parent_issue_id => @issue.id,
                                   :start_date => today,
                                   :due_date => (today + 7))
                     )
    @grandchild = Issue.generate!(
                          attrs.merge(:subject => 'grandchild',
                                      :parent_issue_id => @child1.id,
                                      :start_date => (today - 1),
                                      :due_date => (today + 2))
                        )
    @output_buffer = @gantt.subjects
    # parent task 44px
    assert_select 'div.issue-subject[style*="left:44px"]', /#{@issue.subject}/
    # children 64px
    assert_select 'div.issue-subject[style*="left:64px"]', /child1/
    # children 76px: 64px + 18px(collapse/expand icon's width)
    assert_select 'div.issue-subject[style*="left:82px"]', /child2/
    # grandchild 96px: 84px + 18px(collapse/expand icon's width)
    assert_select 'div.issue-subject[style*="left:102px"]', /grandchild/, @output_buffer
  end

  test "#lines" do
    create_gantt
    @project.enabled_module_names = [:issue_tracking]
    @tracker = Tracker.generate!
    @project.trackers << @tracker
    @version = Version.generate!(:effective_date => (today + 7))
    @project.versions << @version
    @issue = Issue.generate!(:fixed_version => @version,
                             :subject => "gantt#line_for_project",
                             :tracker => @tracker,
                             :project => @project,
                             :done_ratio => 30,
                             :start_date => (today - 1),
                             :due_date => (today + 7))
    @project.issues << @issue
    @output_buffer = @gantt.lines

    assert_select "div.project.task_todo"
    assert_select "div.project.starting"
    assert_select "div.project.ending"
    assert_select "div.label.project", /#{@project.name}/

    assert_select "div.version.task_todo"
    assert_select "div.version.starting"
    assert_select "div.version.ending"
    assert_select "div.label.version", /#{@version.name}/

    assert_select "div.task_todo"
    assert_select "div.task.label", /#{@issue.done_ratio}/
    assert_select "div.tooltip", /#{@issue.subject}/
  end

  test "#selected_column_content" do
    create_gantt
    issue = Issue.generate!
    @gantt.query.column_names = [:assigned_to]
    issue.update(:assigned_to_id => issue.assignable_users.first.id)
    @project.issues << issue
    # :column => assigned_to
    @output_buffer = @gantt.selected_column_content({:column => @gantt.query.columns.last})
    assert_select "div.issue_assigned_to#assigned_to_issue_#{issue.id}"
  end

  test "#subject_for_project" do
    create_gantt
    @output_buffer = @gantt.subject_for_project(@project, :format => :html)
    assert_select 'a[href=?]', "/projects/#{@project.identifier}", :text => /#{@project.name}/
  end

  test "#subject_for_project should style overdue projects" do
    create_gantt
    @project.stubs(:overdue?).returns(true)
    @output_buffer = @gantt.subject_for_project(@project, :format => :html)
    assert_select 'div span.project-overdue'
  end

  test "#subject_for_version" do
    create_gantt
    version = Version.generate!(:name => 'Foo', :effective_date => today, :project => @project)
    @output_buffer = @gantt.subject_for_version(version, :format => :html)
    assert_select 'a[href=?]', "/versions/#{version.to_param}", :text => /Foo/
  end

  test "#subject_for_version should style overdue versions" do
    create_gantt
    version = Version.generate!(:name => 'Foo', :effective_date => today, :project => @project)
    version.stubs(:overdue?).returns(true)
    @output_buffer = @gantt.subject_for_version(version, :format => :html)
    assert_select 'div span.version-overdue'
  end

  test "#subject_for_version should style behind schedule versions" do
    create_gantt
    version = Version.generate!(:name => 'Foo', :effective_date => today, :project => @project)
    version.stubs(:behind_schedule?).returns(true)
    @output_buffer = @gantt.subject_for_version(version, :format => :html)
    assert_select 'div span.version-behind-schedule'
  end

  test "#subject_for_issue" do
    create_gantt
    issue = Issue.generate!(:project => @project)
    @output_buffer = @gantt.subject_for_issue(issue, :format => :html)
    assert_select 'div', :text => /#{issue.subject}/
    assert_select 'a[href=?]', "/issues/#{issue.to_param}", :text => /#{issue.tracker.name} ##{issue.id}/
  end

  test "#subject_for_issue should style overdue issues" do
    create_gantt
    issue = Issue.generate!(:project => @project)
    issue.stubs(:overdue?).returns(true)
    @output_buffer = @gantt.subject_for_issue(issue, :format => :html)
    assert_select 'div span.issue-overdue'
  end

  test "#subject should add an absolute positioned div" do
    create_gantt
    @output_buffer = @gantt.subject('subject', :format => :html)
    assert_select "div[style*=absolute]", :text => 'subject'
  end

  test "#subject should use the indent option to move the div to the right" do
    create_gantt
    @output_buffer = @gantt.subject('subject', :format => :html, :indent => 40)
    # subject 52px: 40px(indent) + 12px(collapse/expand icon's width)
    assert_select 'div[style*="left:58px"]'
  end

  test "#line_for_project" do
    create_gantt
    @project.stubs(:start_date).returns(today - 7)
    @project.stubs(:due_date).returns(today + 7)
    @output_buffer = @gantt.line_for_project(@project, :format => :html)
    assert_select "div.project.label", :text => @project.name
  end

  test "#line_for_version" do
    create_gantt
    version = Version.generate!(:name => 'Foo', :project => @project)
    version.stubs(:start_date).returns(today - 7)
    version.stubs(:due_date).returns(today + 7)
    version.stubs(:visible_fixed_issues => stub(:completed_percent => 30))
    @output_buffer = @gantt.line_for_version(version, :format => :html)
    assert_select "div.version.label", :text => /Foo/
    assert_select "div.version.label", :text => /30%/
  end

  test "#line_for_issue" do
    create_gantt
    issue = Issue.generate!(:project => @project, :start_date => today - 7, :due_date => today + 7, :done_ratio => 30)
    @output_buffer = @gantt.line_for_issue(issue, :format => :html)
    assert_select "div.task.label", :text => /#{issue.status.name}/
    assert_select "div.task.label", :text => /30%/
    assert_select "div.tooltip", /#{issue.subject}/
  end

  test "#line todo line should start from the starting point on the left" do
    create_gantt
    @output_buffer = @gantt.line(today - 7, today + 7, 30, false, 'line', :format => :html, :zoom => 4)
    assert_select 'div.task_todo[style*="left:28px"]', 1
  end

  test "#line todo line should appear if it ends on the leftmost date in the gantt" do
    create_gantt
    [gantt_start - 1, gantt_start].each do |start_date|
      @output_buffer = @gantt.line(start_date, gantt_start, 30, false, 'line', :format => :html, :zoom => 4)
      # the leftmost date (Date.today - 14 days)
      assert_select 'div.task_todo[style*="left:0px"]', 1, @output_buffer
      assert_select 'div.task_todo[style*="width:2px"]', 1, @output_buffer
    end
  end

  test "#line todo line should appear if it starts on the rightmost date in the gantt" do
    create_gantt
    [gantt_end, gantt_end + 1].each do |end_date|
      @output_buffer = @gantt.line(gantt_end, end_date, 30, false, 'line', :format => :html, :zoom => 4)
      # the rightmost date (Date.today + 14 days)
      assert_select 'div.task_todo[style*="left:112px"]', 1, @output_buffer
      assert_select 'div.task_todo[style*="width:2px"]', 1, @output_buffer
    end
  end

  test "#line todo line should be the total width" do
    create_gantt
    @output_buffer = @gantt.line(today - 7, today + 7, 30, false, 'line', :format => :html, :zoom => 4)
    assert_select 'div.task_todo[style*="width:58px"]', 1
  end

  test "#line late line should start from the starting point on the left" do
    create_gantt
    @output_buffer = @gantt.line(today - 7, today + 7, 30, false, 'line', :format => :html, :zoom => 4)
    assert_select 'div.task_late[style*="left:28px"]', 1
  end

  test "#line late line should be the total delayed width" do
    create_gantt
    @output_buffer = @gantt.line(today - 7, today + 7, 30, false, 'line', :format => :html, :zoom => 4)
    assert_select 'div.task_late[style*="width:30px"]', 1
  end

  test "#line late line should be the same width as task_todo if start date and end date are the same day" do
    create_gantt
    @output_buffer = @gantt.line(today - 7, today - 7, 0, false, 'line', :format => :html, :zoom => 4)
    assert_select 'div.task_late[style*="width:2px"]', 1
    assert_select 'div.task_todo[style*="width:2px"]', 1
  end

  test "#line late line should be the same width as task_todo if start date and today are the same day" do
    create_gantt
    @output_buffer = @gantt.line(today, today, 0, false, 'line', :format => :html, :zoom => 4)
    assert_select 'div.task_late[style*="width:2px"]', 1
    assert_select 'div.task_todo[style*="width:2px"]', 1
  end

  test "#line done line should start from the starting point on the left" do
    create_gantt
    @output_buffer = @gantt.line(today - 7, today + 7, 30, false, 'line', :format => :html, :zoom => 4)
    assert_select 'div.task_done[style*="left:28px"]', 1
  end

  test "#line done line should be the width for the done ratio" do
    create_gantt
    @output_buffer = @gantt.line(today - 7, today + 7, 30, false, 'line', :format => :html, :zoom => 4)
    # 15 days * 4 px * 30% - 2 px for borders = 16 px
    assert_select 'div.task_done[style*="width:16px"]', 1
  end

  test "#line done line should be the total width for 100% done ratio" do
    create_gantt
    @output_buffer = @gantt.line(today - 7, today + 7, 100, false, 'line', :format => :html, :zoom => 4)
    # 15 days * 4 px - 2 px for borders = 58 px
    assert_select 'div.task_done[style*="width:58px"]', 1
  end

  test "#line done line should be the total width for 100% done ratio with same start and end dates" do
    create_gantt
    @output_buffer = @gantt.line(today + 7, today + 7, 100, false, 'line', :format => :html, :zoom => 4)
    assert_select 'div.task_done[style*="width:2px"]', 1
  end

  test "#line done line should not be the total done width if the gantt starts after start date" do
    create_gantt
    @output_buffer = @gantt.line(today - 16, today - 2, 30, false, 'line', :format => :html, :zoom => 4)
    assert_select 'div.task_done[style*="left:0px"]', 1
    assert_select 'div.task_done[style*="width:8px"]', 1
  end

  test "#line starting marker should appear at the start date" do
    create_gantt
    @output_buffer = @gantt.line(today - 7, today + 7, 30, true, 'line', :format => :html, :zoom => 4)
    assert_select "div.starting", 1
    assert_select 'div.starting[style*="left:28px"]', 1
    # starting marker on the leftmost boundary of the gantt
    @output_buffer = @gantt.line(gantt_start, today + 7, 30, true, 'line', :format => :html, :zoom => 4)
    assert_select 'div.starting[style*="left:0px"]', 1
  end

  test "#line starting marker should not appear if the start date is before gantt start date" do
    create_gantt
    @output_buffer = @gantt.line(gantt_start - 2, today + 7, 30, true, 'line', :format => :html, :zoom => 4)
    assert_select "div.starting", 0
  end

  test "#line ending marker should appear at the end date" do
    create_gantt
    @output_buffer = @gantt.line(today - 7, today + 7, 30, true, 'line', :format => :html, :zoom => 4)
    assert_select "div.ending", 1
    assert_select 'div.ending[style*="left:88px"]', 1
    # ending marker on the rightmost boundary of the gantt
    @output_buffer = @gantt.line(today - 7, gantt_end, 30, true, 'line', :format => :html, :zoom => 4)
    assert_select 'div.ending[style*="left:116px"]', 1
  end

  test "#line ending marker should not appear if the end date is before gantt start date" do
    create_gantt
    @output_buffer = @gantt.line(gantt_start - 30, gantt_start - 21, 30, true, 'line', :format => :html)
    assert_select "div.ending", 0
  end

  test "#line label should appear at the far left, even if it's before gantt start date" do
    create_gantt
    @output_buffer = @gantt.line(gantt_start - 30, gantt_start - 21, 30, true, 'line', :format => :html)
    assert_select "div.label", :text => 'line'
  end

  test "#column_content_for_issue" do
    create_gantt
    @gantt.query.column_names = [:assigned_to]
    issue = Issue.generate!
    issue.update(:assigned_to_id => issue.assignable_users.first.id)
    @project.issues << issue
    # :column => assigned_to
    options = {:column => @gantt.query.columns.last, :top => 64, :format => :html}
    @output_buffer = @gantt.column_content_for_issue(issue, options)

    assert_select "div.issue_assigned_to#assigned_to_issue_#{issue.id}"
    assert_includes @output_buffer, column_content(options[:column], issue)
  end

  def test_sort_issues_no_date
    project = Project.generate!
    issue1 = Issue.generate!(:subject => "test", :project => project)
    issue2 = Issue.generate!(:subject => "test", :project => project)
    assert issue1.root_id < issue2.root_id
    child1 = Issue.generate!(:parent_issue_id => issue1.id, :subject => 'child',
                             :project => project)
    child2 = Issue.generate!(:parent_issue_id => issue1.id, :subject => 'child',
                             :project => project)
    child3 = Issue.generate!(:parent_issue_id => child1.id, :subject => 'child',
                             :project => project)
    assert_equal child1.root_id, child2.root_id
    assert child1.lft < child2.lft
    assert child3.lft < child2.lft
    issues = [child3, child2, child1, issue2, issue1]
    Redmine::Helpers::Gantt.sort_issues!(issues)
    assert_equal [issue1.id, child1.id, child3.id, child2.id, issue2.id],
                 issues.map{|v| v.id}
  end

  def test_sort_issues_root_only
    project = Project.generate!
    issue1 = Issue.generate!(:subject => "test", :project => project)
    issue2 = Issue.generate!(:subject => "test", :project => project)
    issue3 = Issue.generate!(:subject => "test", :project => project,
                             :start_date => (today - 1))
    issue4 = Issue.generate!(:subject => "test", :project => project,
                             :start_date => (today - 2))
    issues = [issue4, issue3, issue2, issue1]
    Redmine::Helpers::Gantt.sort_issues!(issues)
    assert_equal [issue1.id, issue2.id, issue4.id, issue3.id],
                 issues.map{|v| v.id}
  end

  def test_sort_issues_tree
    project = Project.generate!
    issue1 = Issue.generate!(:subject => "test", :project => project)
    issue2 = Issue.generate!(:subject => "test", :project => project,
                             :start_date => (today - 2))
    issue1_child1 =
      Issue.generate!(:parent_issue_id => issue1.id, :subject => 'child',
                      :project => project)
    issue1_child2 =
      Issue.generate!(:parent_issue_id => issue1.id, :subject => 'child',
                      :project => project, :start_date => (today - 10))
    issue1_child1_child1 =
      Issue.generate!(:parent_issue_id => issue1_child1.id, :subject => 'child',
                      :project => project, :start_date => (today - 8))
    issue1_child1_child2 =
      Issue.generate!(:parent_issue_id => issue1_child1.id, :subject => 'child',
                      :project => project, :start_date => (today - 9))
    issue1_child1_child1_logic = Redmine::Helpers::Gantt.sort_issue_logic(issue1_child1_child1)
    assert_equal [[today - 10, issue1.id], [today - 9, issue1_child1.id],
                  [today - 8, issue1_child1_child1.id]],
                 issue1_child1_child1_logic
    issue1_child1_child2_logic = Redmine::Helpers::Gantt.sort_issue_logic(issue1_child1_child2)
    assert_equal [[today - 10, issue1.id], [today - 9, issue1_child1.id],
                  [today - 9, issue1_child1_child2.id]],
                 issue1_child1_child2_logic
    issues = [issue1_child1_child2, issue1_child1_child1, issue1_child2,
              issue1_child1, issue2, issue1]
    Redmine::Helpers::Gantt.sort_issues!(issues)
    assert_equal [issue1.id, issue1_child1.id, issue1_child2.id,
                  issue1_child1_child2.id, issue1_child1_child1.id, issue2.id],
                 issues.map{|v| v.id}
  end

  def test_sort_versions
    project = Project.generate!
    versions = []
    versions << Version.create!(:project => project, :name => 'test1')
    versions << Version.create!(:project => project, :name => 'test2', :effective_date => '2013-10-25')
    versions << Version.create!(:project => project, :name => 'test3')
    versions << Version.create!(:project => project, :name => 'test4', :effective_date => '2013-10-02')

    assert_equal versions.sort, Redmine::Helpers::Gantt.sort_versions!(versions.dup)
  end

  def test_magick_text
    create_gantt
    assert_equal "'foo\\'bar\\\\baz'", @gantt.send(:magick_text, "foo'bar\\baz")
  end
end
