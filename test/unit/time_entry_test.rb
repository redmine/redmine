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

class TimeEntryTest < ActiveSupport::TestCase
  include Redmine::I18n

  def setup
    User.current = nil
  end

  def test_visibility_with_permission_to_view_all_time_entries
    user = User.generate!
    role = Role.generate!(:permissions => [:view_time_entries], :time_entries_visibility => 'all')
    Role.non_member.remove_permission! :view_time_entries
    project = Project.find(1)
    User.add_to_project user, project, role
    own = TimeEntry.generate! :user => user, :project => project
    other = TimeEntry.generate! :user => User.find(2), :project => project

    assert TimeEntry.visible(user).find_by_id(own.id)
    assert TimeEntry.visible(user).find_by_id(other.id)

    assert own.visible?(user)
    assert other.visible?(user)
  end

  def test_visibility_with_permission_to_view_own_time_entries
    user = User.generate!
    role = Role.generate!(:permissions => [:view_time_entries], :time_entries_visibility => 'own')
    Role.non_member.remove_permission! :view_time_entries
    project = Project.find(1)
    User.add_to_project user, project, role
    own = TimeEntry.generate! :user => user, :project => project
    other = TimeEntry.generate! :user => User.find(2), :project => project

    assert TimeEntry.visible(user).find_by_id(own.id)
    assert_nil TimeEntry.visible(user).find_by_id(other.id)

    assert own.visible?(user)
    assert_equal false, other.visible?(user)
  end

  def test_hours_format
    assertions = {
      "2"      => 2.0,
      "21.1"   => 21.1,
      "2,1"    => 2.1,
      "1,5h"   => 1.5,
      "7:12"   => 7.2,
      "10h"    => 10.0,
      "10 h"   => 10.0,
      "45m"    => 0.75,
      "45 m"   => 0.75,
      "3h15"   => 3.25,
      "3h 15"  => 3.25,
      "3 h 15"   => 3.25,
      "3 h 15m"  => 3.25,
      "3 h 15 m" => 3.25,
      "3 hours"  => 3.0,
      "12min"    => 0.2,
      "12 Min"    => 0.2,
      "0:23"   => Rational(23, 60), # 0.38333333333333336
      "0.9913888888888889" => Rational(59, 60), # 59m 29s is rounded to 59m
      "0.9919444444444444" => 1     # 59m 30s is rounded to 60m
    }
    assertions.each do |k, v|
      t = TimeEntry.new(:hours => k)
      assert v == t.hours && t.hours.is_a?(Rational), "Converting #{k} failed:"
    end
  end

  def test_hours_sum_precision
    # The sum of 10, 10, and 40 minutes should be 1 hour, but in older
    # versions of Redmine, the result was 1.01 hours. This was because
    # TimeEntry#hours was a float value rounded to 2 decimal places.
    #  [0.17, 0.17, 0.67].sum => 1.01

    hours = %w[10m 10m 40m].map {|m| TimeEntry.new(hours: m).hours}
    assert_equal 1, hours.sum
    hours.map {|h| assert h.is_a?(Rational)}
  end

  def test_hours_should_default_to_nil
    assert_nil TimeEntry.new.hours
  end

  def test_should_accept_0_hours
    entry = TimeEntry.generate
    entry.hours = 0
    assert entry.save
  end

  def test_should_not_accept_0_hours_if_disabled
    with_settings :timelog_accept_0_hours => '0' do
      entry = TimeEntry.generate
      entry.hours = 0
      assert !entry.save
      assert entry.errors[:hours].present?
    end
  end

  def test_should_not_accept_more_than_maximum_hours_per_day_and_user
    with_settings :timelog_max_hours_per_day => '8' do
      entry = TimeEntry.generate(:spent_on => '2017-07-16', :hours => 6.0, :user_id => 2)
      assert entry.save

      entry = TimeEntry.generate(:spent_on => '2017-07-16', :hours => 1.5, :user_id => 2)
      assert entry.save

      entry = TimeEntry.generate(:spent_on => '2017-07-16', :hours => 3.0, :user_id => 2)
      assert !entry.save
    end
  end

  def test_activity_id_should_default_activity_id
    project = Project.find(1)
    default_activity = TimeEntryActivity.find(10)
    entry = TimeEntry.new(project: project)
    assert_equal entry.activity_id, default_activity.id

    # If there are project specific activities
    project_specific_default_activity = TimeEntryActivity.create!(name: 'Development', parent_id: 10, project_id: project.id, is_default: false)
    entry = TimeEntry.new(project: project)
    assert_not_equal entry.activity_id, default_activity.id
    assert_equal entry.activity_id, project_specific_default_activity.id
  end

  def test_activity_id_should_be_set_automatically_if_there_is_only_one_activity_available
    project = Project.find(1)
    TimeEntry.destroy_all
    TimeEntryActivity.destroy_all
    only_one_activity = TimeEntryActivity.create!(
      name: 'Development',
      parent_id: nil,
      project_id: nil,
      is_default: false
    )

    entry = TimeEntry.new(project: project)
    assert_equal entry.activity_id, only_one_activity.id
  end

  def test_should_accept_future_dates
    entry = TimeEntry.generate
    entry.spent_on = User.current.today + 1

    assert entry.save
  end

  def test_should_not_accept_future_dates_if_disabled
    with_settings :timelog_accept_future_dates => '0' do
      entry = TimeEntry.generate
      entry.spent_on = User.current.today + 1

      assert !entry.save
      assert entry.errors[:base].present?
    end
  end

  def test_should_require_spent_on
    with_settings :timelog_accept_future_dates => '0' do
      entry = TimeEntry.find(1)
      entry.spent_on = ''

      assert !entry.save
      assert entry.errors[:spent_on].present?
    end
  end

  def test_spent_on_with_blank
    c = TimeEntry.new
    c.spent_on = ''
    assert_nil c.spent_on
  end

  def test_spent_on_with_nil
    c = TimeEntry.new
    c.spent_on = nil
    assert_nil c.spent_on
  end

  def test_spent_on_with_string
    c = TimeEntry.new
    c.spent_on = "2011-01-14"
    assert_equal Date.parse("2011-01-14"), c.spent_on
  end

  def test_spent_on_with_invalid_string
    c = TimeEntry.new
    c.spent_on = "foo"
    assert_nil c.spent_on
  end

  def test_spent_on_with_date
    c = TimeEntry.new
    c.spent_on = Date.today
    assert_equal Date.today, c.spent_on
  end

  def test_spent_on_with_time
    c = TimeEntry.new
    c.spent_on = Time.now
    assert_kind_of Date, c.spent_on
  end

  def test_validate_time_entry
    anon     = User.anonymous
    project  = Project.find(1)
    issue    = Issue.new(:project_id => 1, :tracker_id => 1, :author_id => anon.id, :status_id => 1,
                         :priority => IssuePriority.first, :subject => 'test_create',
                         :description => 'IssueTest#test_create', :estimated_hours => '1:30')
    assert issue.save
    activity = TimeEntryActivity.find_by_name('Design')
    te = TimeEntry.create(:spent_on => '2010-01-01',
                          :hours    => 100000,
                          :issue    => issue,
                          :project  => project,
                          :user     => anon,
                          :author     => anon,
                          :activity => activity)
    assert_equal 1, te.errors.count
  end

  def test_acitivity_should_belong_to_project_activities
    activity = TimeEntryActivity.create!(:name => 'Other project activity', :project_id => 2, :active => true)

    entry = TimeEntry.new(:spent_on => Date.today, :hours => 1.0, :user => User.find(1), :project_id => 1, :activity => activity)
    assert entry.invalid?
    assert_include I18n.translate('activerecord.errors.messages.inclusion'), entry.errors[:activity_id]
  end

  def test_spent_on_with_2_digits_year_should_not_be_valid
    entry = TimeEntry.new(:project => Project.find(1), :user => User.find(1), :activity => TimeEntryActivity.first, :hours => 1)
    entry.spent_on = "09-02-04"
    assert entry.invalid?
    assert_include I18n.translate('activerecord.errors.messages.not_a_date'), entry.errors[:spent_on]
  end

  def test_set_project_if_nil
    anon     = User.anonymous
    project  = Project.find(1)
    issue    = Issue.new(:project_id => 1, :tracker_id => 1, :author_id => anon.id, :status_id => 1,
                         :priority => IssuePriority.first, :subject => 'test_create',
                         :description => 'IssueTest#test_create', :estimated_hours => '1:30')
    assert issue.save
    activity = TimeEntryActivity.find_by_name('Design')
    te = TimeEntry.create(:spent_on => '2010-01-01',
                          :hours    => 10,
                          :issue    => issue,
                          :user     => anon,
                          :activity => activity)
    assert_equal project.id, te.project.id
  end

  def test_create_with_required_issue_id_and_comment_should_be_validated
    set_language_if_valid 'en'
    with_settings :timelog_required_fields => ['issue_id', 'comments'] do
      entry = TimeEntry.new(:project => Project.find(1),
                            :spent_on => Date.today,
                            :author => User.find(1),
                            :user => User.find(1),
                            :activity => TimeEntryActivity.first,
                            :hours => 1)
      assert !entry.save
      assert_equal ["Comment cannot be blank", "Issue cannot be blank"], entry.errors.full_messages.sort
    end
  end

  def test_create_should_validate_user_id
    set_language_if_valid 'en'
    entry = TimeEntry.new(:spent_on => '2010-01-01',
                          :hours    => 10,
                          :project_id => 1,
                          :user_id    => 4)

    assert !entry.save
    assert_equal ["User is invalid"], entry.errors.full_messages.sort
  end

  def test_assignable_users_should_include_active_project_members_with_log_time_permission
    Role.find(2).remove_permission! :log_time
    time_entry = TimeEntry.find(1)

    assert_equal [2], time_entry.assignable_users.map(&:id)
  end
end
