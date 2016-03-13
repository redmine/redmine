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

require File.expand_path('../../test_helper', __FILE__)

class VersionTest < ActiveSupport::TestCase
  fixtures :projects, :users, :issues, :issue_statuses, :trackers,
           :enumerations, :versions, :projects_trackers

  def test_create
    v = Version.new(:project => Project.find(1), :name => '1.1',
                    :effective_date => '2011-03-25')
    assert v.save
    assert_equal 'open', v.status
    assert_equal 'none', v.sharing
  end

  def test_invalid_effective_date_validation
    v = Version.new(:project => Project.find(1), :name => '1.1',
                    :effective_date => '99999-01-01')
    assert !v.valid?
    v.effective_date = '2012-11-33'
    assert !v.valid?
    v.effective_date = '2012-31-11'
    assert !v.valid?
    v.effective_date = '-2012-31-11'
    assert !v.valid?
    v.effective_date = 'ABC'
    assert !v.valid?
    assert_include I18n.translate('activerecord.errors.messages.not_a_date'),
                   v.errors[:effective_date]
  end

  def test_progress_should_be_0_with_no_assigned_issues
    project = Project.find(1)
    v = Version.create!(:project => project, :name => 'Progress')
    assert_equal 0, v.completed_percent
    assert_equal 0, v.closed_percent
  end

  def test_progress_should_be_0_with_unbegun_assigned_issues
    project = Project.find(1)
    v = Version.create!(:project => project, :name => 'Progress')
    add_issue(v)
    add_issue(v, :done_ratio => 0)
    assert_progress_equal 0, v.completed_percent
    assert_progress_equal 0, v.closed_percent
  end

  def test_progress_should_be_100_with_closed_assigned_issues
    project = Project.find(1)
    status = IssueStatus.where(:is_closed => true).first
    v = Version.create!(:project => project, :name => 'Progress')
    add_issue(v, :status => status)
    add_issue(v, :status => status, :done_ratio => 20)
    add_issue(v, :status => status, :done_ratio => 70, :estimated_hours => 25)
    add_issue(v, :status => status, :estimated_hours => 15)
    assert_progress_equal 100.0, v.completed_percent
    assert_progress_equal 100.0, v.closed_percent
  end

  def test_progress_should_consider_done_ratio_of_open_assigned_issues
    project = Project.find(1)
    v = Version.create!(:project => project, :name => 'Progress')
    add_issue(v)
    add_issue(v, :done_ratio => 20)
    add_issue(v, :done_ratio => 70)
    assert_progress_equal (0.0 + 20.0 + 70.0)/3, v.completed_percent
    assert_progress_equal 0, v.closed_percent
  end

  def test_progress_should_consider_closed_issues_as_completed
    project = Project.find(1)
    v = Version.create!(:project => project, :name => 'Progress')
    add_issue(v)
    add_issue(v, :done_ratio => 20)
    add_issue(v, :status => IssueStatus.where(:is_closed => true).first)
    assert_progress_equal (0.0 + 20.0 + 100.0)/3, v.completed_percent
    assert_progress_equal (100.0)/3, v.closed_percent
  end

  def test_progress_should_consider_estimated_hours_to_weight_issues
    project = Project.find(1)
    v = Version.create!(:project => project, :name => 'Progress')
    add_issue(v, :estimated_hours => 10)
    add_issue(v, :estimated_hours => 20, :done_ratio => 30)
    add_issue(v, :estimated_hours => 40, :done_ratio => 10)
    add_issue(v, :estimated_hours => 25, :status => IssueStatus.where(:is_closed => true).first)
    assert_progress_equal (10.0*0 + 20.0*0.3 + 40*0.1 + 25.0*1)/95.0*100, v.completed_percent
    assert_progress_equal 25.0/95.0*100, v.closed_percent
  end

  def test_progress_should_consider_average_estimated_hours_to_weight_unestimated_issues
    project = Project.find(1)
    v = Version.create!(:project => project, :name => 'Progress')
    add_issue(v, :done_ratio => 20)
    add_issue(v, :status => IssueStatus.where(:is_closed => true).first)
    add_issue(v, :estimated_hours => 10, :done_ratio => 30)
    add_issue(v, :estimated_hours => 40, :done_ratio => 10)
    assert_progress_equal (25.0*0.2 + 25.0*1 + 10.0*0.3 + 40.0*0.1)/100.0*100, v.completed_percent
    assert_progress_equal 25.0/100.0*100, v.closed_percent
  end

  def test_should_sort_scheduled_then_unscheduled_versions
    Version.delete_all
    v4 = Version.create!(:project_id => 1, :name => 'v4')
    v3 = Version.create!(:project_id => 1, :name => 'v2', :effective_date => '2012-07-14')
    v2 = Version.create!(:project_id => 1, :name => 'v1')
    v1 = Version.create!(:project_id => 1, :name => 'v3', :effective_date => '2012-08-02')
    v5 = Version.create!(:project_id => 1, :name => 'v5', :effective_date => '2012-07-02')

    assert_equal [v5, v3, v1, v2, v4], [v1, v2, v3, v4, v5].sort
    assert_equal [v5, v3, v1, v2, v4], Version.sorted.to_a
  end

  def test_should_sort_versions_with_same_date_by_name
    v1 = Version.new(:effective_date => '2014-12-03', :name => 'v2')
    v2 = Version.new(:effective_date => '2014-12-03', :name => 'v1')
    assert_equal [v2, v1], [v1, v2].sort
  end

  def test_completed_should_be_false_when_due_today
    version = Version.create!(:project_id => 1, :effective_date => Date.today, :name => 'Due today')
    assert_equal false, version.completed?
  end

  def test_completed_should_be_true_when_closed
    version = Version.create!(:project_id => 1, :status => 'closed', :name => 'Closed')
    assert_equal true, version.completed?
  end

  test "#behind_schedule? should be false if there are no issues assigned" do
    version = Version.generate!(:effective_date => Date.yesterday)
    assert_equal false, version.behind_schedule?
  end

  test "#behind_schedule? should be false if there is no effective_date" do
    version = Version.generate!(:effective_date => nil)
    assert_equal false, version.behind_schedule?
  end

  test "#behind_schedule? should be false if all of the issues are ahead of schedule" do
    version = Version.create!(:project_id => 1, :name => 'test', :effective_date => 7.days.from_now.to_date)
    add_issue(version, :start_date => 7.days.ago, :done_ratio => 60) # 14 day span, 60% done, 50% time left
    add_issue(version, :start_date => 7.days.ago, :done_ratio => 60) # 14 day span, 60% done, 50% time left
    assert_equal 60, version.completed_percent
    assert_equal false, version.behind_schedule?
  end

  test "#behind_schedule? should be true if any of the issues are behind schedule" do
    version = Version.create!(:project_id => 1, :name => 'test', :effective_date => 7.days.from_now.to_date)
    add_issue(version, :start_date => 7.days.ago, :done_ratio => 60) # 14 day span, 60% done, 50% time left
    add_issue(version, :start_date => 7.days.ago, :done_ratio => 20) # 14 day span, 20% done, 50% time left
    assert_equal 40, version.completed_percent
    assert_equal true, version.behind_schedule?
  end

  test "#behind_schedule? should be false if all of the issues are complete" do
    version = Version.create!(:project_id => 1, :name => 'test', :effective_date => 7.days.from_now.to_date)
    add_issue(version, :start_date => 14.days.ago, :done_ratio => 100, :status => IssueStatus.find(5)) # 7 day span
    add_issue(version, :start_date => 14.days.ago, :done_ratio => 100, :status => IssueStatus.find(5)) # 7 day span
    assert_equal 100, version.completed_percent
    assert_equal false, version.behind_schedule?
  end

  test "#estimated_hours should return 0 with no assigned issues" do
    version = Version.generate!
    assert_equal 0, version.estimated_hours
  end

  test "#estimated_hours should return 0 with no estimated hours" do
    version = Version.create!(:project_id => 1, :name => 'test')
    add_issue(version)
    assert_equal 0, version.estimated_hours
  end

  test "#estimated_hours should return return the sum of estimated hours" do
    version = Version.create!(:project_id => 1, :name => 'test')
    add_issue(version, :estimated_hours => 2.5)
    add_issue(version, :estimated_hours => 5)
    assert_equal 7.5, version.estimated_hours
  end

  test "#estimated_hours should return the sum of leaves estimated hours" do
    version = Version.create!(:project_id => 1, :name => 'test')
    parent = add_issue(version)
    add_issue(version, :estimated_hours => 2.5, :parent_issue_id => parent.id)
    add_issue(version, :estimated_hours => 5, :parent_issue_id => parent.id)
    assert_equal 7.5, version.estimated_hours
  end

  test "should update all issue's fixed_version associations in case the hierarchy changed XXX" do
    User.current = User.find(1) # Need the admin's permissions

    @version = Version.find(7)
    # Separate hierarchy
    project_1_issue = Issue.find(1)
    project_1_issue.fixed_version = @version
    assert project_1_issue.save, project_1_issue.errors.full_messages.to_s

    project_5_issue = Issue.find(6)
    project_5_issue.fixed_version = @version
    assert project_5_issue.save

    # Project
    project_2_issue = Issue.find(4)
    project_2_issue.fixed_version = @version
    assert project_2_issue.save

    # Update the sharing
    @version.sharing = 'none'
    assert @version.save

    # Project 1 now out of the shared scope
    project_1_issue.reload
    assert_equal nil, project_1_issue.fixed_version,
                "Fixed version is still set after changing the Version's sharing"

    # Project 5 now out of the shared scope
    project_5_issue.reload
    assert_equal nil, project_5_issue.fixed_version,
                "Fixed version is still set after changing the Version's sharing"

    # Project 2 issue remains
    project_2_issue.reload
    assert_equal @version, project_2_issue.fixed_version
  end

  def test_deletable_should_return_true_when_not_referenced
    version = Version.generate!

    assert_equal true, version.deletable?
  end

  def test_deletable_should_return_false_when_referenced_by_an_issue
    version = Version.generate!
    Issue.generate!(:fixed_version => version)

    assert_equal false, version.deletable?
  end

  def test_deletable_should_return_false_when_referenced_by_a_custom_field
    version = Version.generate!
    field = IssueCustomField.generate!(:field_format => 'version')
    value = CustomValue.create!(:custom_field => field, :customized => Issue.first, :value => version.id)

    assert_equal false, version.deletable?
  end

  private

  def add_issue(version, attributes={})
    Issue.create!({:project => version.project,
                   :fixed_version => version,
                   :subject => 'Test',
                   :author => User.first,
                   :tracker => version.project.trackers.first}.merge(attributes))
  end

  def assert_progress_equal(expected_float, actual_float, message="")
    assert_in_delta(expected_float, actual_float, 0.000001, message="")
  end
end
