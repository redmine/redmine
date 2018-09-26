# Redmine - project management software
# Copyright (C) 2006-2017  Jean-Philippe Lang
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

class IssuesTest < ApplicationSystemTestCase
  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles,
           :trackers, :projects_trackers, :enabled_modules, :issue_statuses, :issues,
           :enumerations, :custom_fields, :custom_values, :custom_fields_trackers,
           :watchers, :journals, :journal_details, :versions

  def test_create_issue
    log_user('jsmith', 'jsmith')
    visit '/projects/ecookbook/issues/new'
    within('form#issue-form') do
      select 'Bug', :from => 'Tracker'
      select 'Low', :from => 'Priority'
      fill_in 'Subject', :with => 'new test issue'
      fill_in 'Description', :with => 'new issue'
      select '0 %', :from => 'Done'
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

  def test_create_issue_with_form_update
    field1 = IssueCustomField.create!(
      :field_format => 'string',
      :name => 'Field1',
      :is_for_all => true,
      :trackers => Tracker.where(:id => [1, 2])
    )
    field2 = IssueCustomField.create!(
      :field_format => 'string',
      :name => 'Field2',
      :is_for_all => true,
      :trackers => Tracker.where(:id => 2)
    )

    Role.non_member.add_permission! :add_issues
    Role.non_member.remove_permission! :edit_issues, :add_issue_notes

    log_user('someone', 'foo')
    visit '/projects/ecookbook/issues/new'
    assert page.has_no_content?(field2.name)
    assert page.has_content?(field1.name)

    fill_in 'Subject', :with => 'New test issue'
    fill_in 'Description', :with => 'New test issue description'
    fill_in field1.name, :with => 'CF1 value'
    select 'Low', :from => 'Priority'

    # field2 should show up when changing tracker
    select 'Feature request', :from => 'Tracker'
    assert page.has_content?(field2.name)
    assert page.has_content?(field1.name)

    fill_in field2.name, :with => 'CF2 value'
    assert_difference 'Issue.count' do
      page.first(:button, 'Create').click
    end

    issue = Issue.order('id desc').first
    assert_equal 'New test issue', issue.subject
    assert_equal 'New test issue description', issue.description
    assert_equal 'Low', issue.priority.name
    assert_equal 'CF1 value', issue.custom_field_value(field1)
    assert_equal 'CF2 value', issue.custom_field_value(field2)
  end

  def test_create_issue_with_watchers
    user = User.generate!(:firstname => 'Some', :lastname => 'Watcher')
    assert_equal 'Some Watcher', user.name
    log_user('jsmith', 'jsmith')
    visit '/projects/ecookbook/issues/new'
    fill_in 'Subject', :with => 'Issue with watchers'
    # Add a project member as watcher
    check 'Dave Lopper'
    # Search for another user
    assert page.has_no_css?('form#new-watcher-form')
    assert page.has_no_content?('Some Watcher')
    click_link 'Search for watchers to add'
    within('form#new-watcher-form') do
      fill_in 'user_search', :with => 'watch'
      assert page.has_content?('Some Watcher')
      check 'Some Watcher'
      click_button 'Add'
    end
    assert page.has_css?('form#issue-form')
    assert page.has_css?('p#watchers_form')
    using_wait_time(30) do
      within('span#watchers_inputs') do
        within("label#issue_watcher_user_ids_#{user.id}") do
          assert has_content?('Some Watcher'), "No watcher content"
        end
      end
    end
    assert_difference 'Issue.count' do
      find('input[name=commit]').click
    end

    issue = Issue.order('id desc').first
    assert_equal ['Dave Lopper', 'Some Watcher'], issue.watcher_users.map(&:name).sort
  end

  def test_create_issue_with_attachment
    set_tmp_attachments_directory
    log_user('jsmith', 'jsmith')

    issue = new_record(Issue) do
      visit '/projects/ecookbook/issues/new'
      fill_in 'Subject', :with => 'Issue with attachment'
      attach_file 'attachments[dummy][file]', Rails.root.join('test/fixtures/files/testfile.txt')
      fill_in 'attachments[1][description]', :with => 'Some description'
      click_on 'Create'
    end
    assert_equal 1, issue.attachments.count
    assert_equal 'Some description', issue.attachments.first.description
  ensure
    set_fixtures_attachments_directory
  end

  def test_create_issue_with_new_target_version
    log_user('jsmith', 'jsmith')

    assert_difference 'Issue.count' do
      assert_difference 'Version.count' do
        visit '/projects/ecookbook/issues/new'
        fill_in 'Subject', :with => 'With a new version'
        click_on 'New version'
        within '#ajax-modal' do
          fill_in 'Name', :with => '4.0'
          click_on 'Create'
        end
        click_on 'Create'
      end
    end

    issue = Issue.order('id desc').first
    assert_not_nil issue.fixed_version
    assert_equal '4.0', issue.fixed_version.name
  end

  def test_preview_issue_description
    log_user('jsmith', 'jsmith')
    visit '/projects/ecookbook/issues/new'
    within('form#issue-form') do
      fill_in 'Subject', :with => 'new issue subject'
      fill_in 'Description', :with => 'new issue description'
      click_link 'Preview'
      find 'div.wiki-preview', :visible => true, :text => 'new issue description'
    end
    assert_difference 'Issue.count' do
      click_button('Create')
    end

    issue = Issue.order('id desc').first
    assert_equal 'new issue description', issue.description
  end

  def test_update_issue_with_form_update
    field = IssueCustomField.create!(
      :field_format => 'string',
      :name => 'Form update CF',
      :is_for_all => true,
      :trackers => Tracker.where(:name => 'Feature request')
    )

    Role.non_member.add_permission! :edit_issues, :add_issues
    Role.non_member.remove_permission! :add_issue_notes

    log_user('someone', 'foo')
    visit '/issues/1'
    assert page.has_no_content?('Form update CF')

    page.first(:link, 'Edit').click
    # the custom field should show up when changing tracker
    select 'Feature request', :from => 'Tracker'
    assert page.has_content?('Form update CF')

    fill_in 'Form update', :with => 'CF value'
    assert_no_difference 'Issue.count' do
      page.first(:button, 'Submit').click
    end

    issue = Issue.find(1)
    assert_equal 'CF value', issue.custom_field_value(field)
  end

  def test_remove_issue_watcher_from_sidebar
    user = User.find(3)
    Watcher.create!(:watchable => Issue.find(1), :user => user)

    log_user('jsmith', 'jsmith')
    visit '/issues/1'
    assert page.first('#sidebar').has_content?('Watchers (1)')
    assert page.first('#sidebar').has_content?(user.name)
    assert_difference 'Watcher.count', -1 do
      page.first('ul.watchers .user-3 a.delete').click
      assert page.first('#sidebar').has_content?('Watchers (0)')
    end
    assert page.first('#sidebar').has_no_content?(user.name)
  end

  def test_watch_should_update_watchers_list
    user = User.find(2)
    log_user('jsmith', 'jsmith')
    visit '/issues/1'
    assert page.first('#sidebar').has_content?('Watchers (0)')

    page.first('a.issue-1-watcher').click
    assert page.first('#sidebar').has_content?('Watchers (1)')
    assert page.first('#sidebar').has_content?(user.name)
  end

  def test_watch_issue_via_context_menu
    log_user('jsmith', 'jsmith')
    visit '/issues'
    assert page.has_css?('tr#issue-1')
    find('tr#issue-1 td.updated_on').click
    page.execute_script "$('tr#issue-1 td.updated_on').trigger('contextmenu');"
    assert_difference 'Watcher.count' do
      within('#context-menu') do
        click_link 'Watch'
      end
      # wait for ajax response
      assert page.has_css?('#context-menu .issue-1-watcher.icon-fav')
      assert page.has_css?('tr#issue-1')
    end
    assert Issue.find(1).watched_by?(User.find_by_login('jsmith'))
  end

  def test_bulk_watch_issues_via_context_menu
    log_user('jsmith', 'jsmith')
    visit '/issues'
    assert page.has_css?('tr#issue-1')
    assert page.has_css?('tr#issue-4')
    find('tr#issue-1 input[type=checkbox]').click
    find('tr#issue-4 input[type=checkbox]').click
    page.execute_script "$('tr#issue-1 td.updated_on').trigger('contextmenu');"
    assert_difference 'Watcher.count', 2 do
      within('#context-menu') do
        click_link 'Watch'
      end
      # wait for ajax response
      assert page.has_css?('#context-menu .issue-bulk-watcher.icon-fav')
      assert page.has_css?('tr#issue-1')
      assert page.has_css?('tr#issue-4')
    end
    assert Issue.find(1).watched_by?(User.find_by_login('jsmith'))
    assert Issue.find(4).watched_by?(User.find_by_login('jsmith'))
  end

  def test_issue_list_with_default_totalable_columns
    log_user('admin', 'admin')
    with_settings :issue_list_default_totals => ['estimated_hours'] do
      visit '/projects/ecookbook/issues'
      # Check that the page shows the Estimated hours total
      assert page.has_css?('p.query-totals')
      assert page.has_css?('span.total-for-estimated-hours')
      # Open the Options of the form (necessary for having the totalable columns options clickable) 
      page.all('legend')[1].click
      # Deselect the default totalable column (none should be left) 
      page.first('input[name="t[]"][value="estimated_hours"]').click
      within('#query_form') do
        click_link 'Apply'
      end
      # Check that Totals are not present in the reloaded page
      assert !page.has_css?('p.query-totals')
      assert !page.has_css?('span.total-for-estimated-hours')
    end
  end

  def test_update_journal_notes_with_preview
    log_user('admin', 'admin')

    visit '/issues/1'
    # Click on the edit button
    page.first('#change-2 a.icon-edit').click
    # Check that the textarea is displayed
    assert page.has_css?('#change-2 textarea')
    assert page.first('#change-2 textarea').has_content?('Some notes with Redmine links')
    # Update the notes
    fill_in 'Notes', :with => 'Updated notes'
    # Preview the change
    page.first('#change-2 a.tab-preview').click
    assert page.has_css?('#preview_journal_2_notes')
    assert page.first('#preview_journal_2_notes').has_content?('Updated notes')
    # Save
    click_on 'Save'

    sleep 1
    assert_equal 'Updated notes', Journal.find(2).notes
  end

  def test_index_as_csv_should_reflect_sort
    log_user('admin', 'admin')

    visit '/issues'
    # Sort issues by subject
    click_on 'Subject'
    click_on 'CSV'
    click_on 'Export'

    csv = CSV.read(downloaded_file)
    subject_index = csv.shift.index('Subject')
    subjects = csv.map {|row| row[subject_index]}
    assert_equal subjects.sort, subjects
  end
end
