# Redmine - project management software
# Copyright (C) 2006-2013  Jean-Philippe Lang
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

require File.expand_path('../base', __FILE__)

class Redmine::UiTest::IssuesTest < Redmine::UiTest::Base
  fixtures :projects, :users, :roles, :members, :member_roles,
           :trackers, :projects_trackers, :enabled_modules, :issue_statuses, :issues,
           :enumerations, :custom_fields, :custom_values, :custom_fields_trackers,
           :watchers

  # create an issue
  def test_add_issue
    log_user('jsmith', 'jsmith')
    visit new_issue_path(:project_id => 1)
    within('form#issue-form') do
      select 'Bug', :from => 'Tracker'
      select 'Low', :from => 'Priority'
      fill_in 'Subject', :with => 'new test issue'
      fill_in 'Description', :with => 'new issue'
      select '0 %', :from => 'Done'
      fill_in 'Due date', :with => ''
      select '', :from => 'Assignee'
      fill_in 'Searchable field', :with => 'Value for field 2'
      # click_button 'Create' would match both 'Create' and 'Create and continue' buttons
      find('input[name=commit]').click
    end

    # find created issue
    issue = Issue.find_by_subject("new test issue")
    assert_kind_of Issue, issue

    # check redirection
    find 'div#flash_notice', :visible => true, :text => "Issue \##{issue.id} created."
    assert_equal issue_path(:id => issue), current_path

    # check issue attributes
    assert_equal 'jsmith', issue.author.login
    assert_equal 1, issue.project.id
    assert_equal IssueStatus.find_by_name('New'), issue.status 
    assert_equal Tracker.find_by_name('Bug'), issue.tracker
    assert_equal IssuePriority.find_by_name('Low'), issue.priority
    assert_equal 'Value for field 2', issue.custom_field_value(CustomField.find_by_name('Searchable field'))
  end

  def test_create_issue_with_watchers
    User.generate!(:firstname => 'Some', :lastname => 'Watcher')

    assert_difference 'Issue.count' do
      log_user('jsmith', 'jsmith')
      visit '/projects/ecookbook/issues/new'
      fill_in 'Subject', :with => 'Issue with watchers'
      # Add a project member as watcher
      check 'Dave Lopper'
      # Search for another user
      click_link 'Search for watchers to add'
      within('form#new-watcher-form') do
        assert page.has_content?('Some One')
        fill_in 'user_search', :with => 'watch'
        assert page.has_no_content?('Some One')
        check 'Some Watcher'
        click_button 'Add'
      end
      find('input[name=commit]').click
    end

    issue = Issue.order('id desc').first
    assert_equal ['Dave Lopper', 'Some Watcher'], issue.watcher_users.map(&:name).sort
  end

	# TODO: `fill_in 'Description'` makes all visit calls inoperative
  # and breaks all tests that run after that
  def test_preview_issue_description
    skip("Breaks the test suite")

    log_user('jsmith', 'jsmith')
    visit new_issue_path(:project_id => 1)
    within('form#issue-form') do
      fill_in 'Description', :with => 'new issue description'
      click_link 'Preview'
    end
    find 'div#preview fieldset', :visible => true, :text => 'new issue description'
  end

  def test_watch_issue_via_context_menu
    log_user('jsmith', 'jsmith')
    visit '/issues'
    find('tr#issue-1 td.updated_on').click
    page.execute_script "$('tr#issue-1 td.updated_on').trigger('contextmenu');"
    assert_difference 'Watcher.count' do
      within('#context-menu') do
        click_link 'Watch'
      end
    end
    assert Issue.find(1).watched_by?(User.find_by_login('jsmith'))
  end

  def test_bulk_watch_issues_via_context_menu
    log_user('jsmith', 'jsmith')
    visit '/issues'
    find('tr#issue-1 input[type=checkbox]').click
    find('tr#issue-4 input[type=checkbox]').click
    page.execute_script "$('tr#issue-1 td.updated_on').trigger('contextmenu');"
    assert_difference 'Watcher.count', 2 do
      within('#context-menu') do
        click_link 'Watch'
      end
    end
    assert Issue.find(1).watched_by?(User.find_by_login('jsmith'))
    assert Issue.find(4).watched_by?(User.find_by_login('jsmith'))
  end
end
