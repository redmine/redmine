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

require File.expand_path('../../application_system_test_case', __FILE__)

Capybara.default_max_wait_time = 2

class TimelogTest < ApplicationSystemTestCase
  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles,
           :trackers, :projects_trackers, :enabled_modules, :issue_statuses, :issues,
           :enumerations, :custom_fields, :custom_values, :custom_fields_trackers,
           :time_entries

  def test_changing_project_should_update_activities
    project = Project.find(1)
    TimeEntryActivity.create!(:name => 'Design', :project => project, :parent => TimeEntryActivity.find_by_name('Design'), :active => false)

    log_user 'jsmith', 'jsmith'
    visit '/time_entries/new'
    within 'select#time_entry_activity_id' do
      assert has_content?('Development')
      assert has_content?('Design')
    end

    within 'form#new_time_entry' do
      select 'eCookbook', :from => 'Project'
    end
    within 'select#time_entry_activity_id' do
      assert has_content?('Development')
      assert !has_content?('Design')
    end
  end

  def test_bulk_edit
    log_user 'jsmith', 'jsmith'
    visit '/time_entries/bulk_edit?ids[]=1&ids[]=2&ids[]=3'
    fill_in 'Hours', :with => '8.5'
    select 'QA', :from => 'Activity'
    page.first(:button, 'Submit').click

    entries = TimeEntry.where(:id => [1,2,3]).to_a
    assert entries.all? {|entry| entry.hours == 8.5}
    assert entries.all? {|entry| entry.activity.name == 'QA'}
  end

  def test_bulk_edit_with_failure
    log_user 'jsmith', 'jsmith'
    visit '/time_entries/bulk_edit?ids[]=1&ids[]=2&ids[]=3'
    fill_in 'Hours', :with => 'A'
    page.first(:button, 'Submit').click

    assert page.has_css?('#errorExplanation')
    fill_in 'Hours', :with => '7'
    page.first(:button, 'Submit').click

    assert_equal "/projects/ecookbook/time_entries", current_path
    entries = TimeEntry.where(:id => [1,2,3]).to_a
    assert entries.all? {|entry| entry.hours == 7.0}
  end

  def test_default_query_setting
    with_settings :default_language => 'en', :force_default_language_for_anonymous => '1' do
      # Display the list with the default settings
      visit '/time_entries'
      within 'table.time-entries thead' do
        assert page.has_no_link?('Tracker')
        assert page.has_text?('Comment')
      end
    end

    # Change the default columns
    log_user 'admin', 'admin'
    visit '/settings?tab=timelog'
    # Remove a column
    select 'Comment', :from => 'Selected Columns'
    page.first('input[type=button].move-left').click
    # Add a column
    select 'Tracker', :from => 'Available Columns'
    page.first('input[type=button].move-right').click
    click_on 'Save'

    # Display the list with updated settings
    visit '/time_entries'
    within 'table.time-entries thead' do
      assert page.has_link?('Tracker')
      assert page.has_no_text?('Comment')
    end
  end
end
