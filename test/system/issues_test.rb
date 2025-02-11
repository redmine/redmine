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

require_relative '../application_system_test_case'

class IssuesSystemTest < ApplicationSystemTestCase
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
    find 'div#flash_notice', :visible => true, :text => "Issue ##{issue.id} created."
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
  end

  def test_create_issue_with_attachment_when_user_is_not_a_member
    set_tmp_attachments_directory
    # Set no permission to non-member role
    non_member_role = Role.where(:builtin => Role::BUILTIN_NON_MEMBER).first
    non_member_role.permissions = []
    non_member_role.save
    # Set role "Reporter" to non-member users on project ecookbook
    membership = Member.find_or_create_by(user_id: Group.non_member.id, project_id: 1)
    membership.roles = [Role.find(3)] # Reporter
    membership.save
    log_user('someone', 'foo')
    issue = new_record(Issue) do
      visit '/projects/ecookbook/issues/new'
      fill_in 'Subject', :with => 'Issue with attachment'
      attach_file 'attachments[dummy][file]', Rails.root.join('test/fixtures/files/testfile.txt')
      fill_in 'attachments[1][description]', :with => 'Some description'
      click_on 'Create'
    end
    assert_equal 1, issue.attachments.count
    assert_equal 'Some description', issue.attachments.first.description
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

  test "update issue with form update" do
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
    assert page.has_no_select?("issue_status_id")
    # the custom field should show up when changing tracker
    select 'Feature request', :from => 'Tracker'
    assert page.has_content?('Form update CF')

    fill_in 'Form update CF', :with => 'CF value'
    assert_no_difference 'Issue.count' do
      page.first(:button, 'Submit').click
    end
    assert page.has_css?('#flash_notice')
    issue = Issue.find(1)
    assert_equal 'CF value', issue.custom_field_value(field)
  end

  test "update issue status" do
    issue = Issue.generate!
    log_user('jsmith', 'jsmith')
    visit "/issues/#{issue.id}"
    page.first(:link, 'Edit').click
    assert page.has_select?("issue_status_id", selected: "New")
    page.find("#issue_status_id").select("Closed")
    assert_no_difference 'Issue.count' do
      page.first(:button, 'Submit').click
    end
    assert page.has_css?('#flash_notice')
    assert_equal 5, issue.reload.status.id
  end

  def test_update_issue_with_form_update_should_keep_newly_added_attachments
    set_tmp_attachments_directory
    log_user('jsmith', 'jsmith')

    visit '/issues/2'
    page.first(:link, 'Edit').click
    attach_file 'attachments[dummy][file]', Rails.root.join('test/fixtures/files/testfile.txt')

    assert page.has_css?('span#attachments_1')

    page.find("#issue_status_id").select("Closed")

    # check that attachment still exists on the page
    assert page.has_css?('span#attachments_1')

    click_on 'Submit'

    assert_equal 3, Issue.find(2).attachments.count
  end

  test "removing issue shows confirm dialog" do
    log_user('jsmith', 'jsmith')
    visit '/issues/1'
    page.accept_confirm /Are you sure/ do
      first('#content span.icon-actions').click
      first('#content a.icon-del').click
    end
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
    jsmith = User.find_by_login('jsmith')
    issue1 = Issue.find(1)
    assert_not issue1.reload.watched_by?(jsmith)
    assert page.has_css?('tr#issue-1')
    find('tr#issue-1 td.updated_on').click
    find('tr#issue-1 td.updated_on').right_click
    assert page.has_css?('#context-menu .issue-1-watcher.icon-fav-off')
    assert_difference 'Watcher.count' do
      within('#context-menu') do
        click_link 'Watch'
      end
      # wait for ajax response
      assert page.has_css?('#context-menu .issue-1-watcher.icon-fav')
      assert page.has_css?('tr#issue-1')
    end
    assert issue1.reload.watched_by?(jsmith)
  end

  def test_change_watch_or_unwatch_icon_from_sidebar
    user = User.find(2)
    log_user('jsmith', 'jsmith')
    visit '/issues/1'
    assert page.has_css?('#content .contextual .issue-1-watcher.icon-fav-off')
    # add watcher 'jsmith' from sidebar
    page.find('#watchers .contextual a', :text => 'Add').click
    page.find('#users_for_watcher label', :text => 'John Smith').click
    page.find('#new-watcher-form p.buttons input[type=submit]').click
    assert page.has_css?('#content .contextual .issue-1-watcher.icon-fav')
    # remove watcher 'jsmith' from sidebar
    page.find('#watchers ul li.user-2 a.delete').click
    assert page.has_css?('#content .contextual .issue-1-watcher.icon-fav-off')
  end

  def test_bulk_watch_issues_via_context_menu
    log_user('jsmith', 'jsmith')
    visit '/issues'
    jsmith = User.find_by_login('jsmith')
    issue1 = Issue.find(1)
    issue4 = Issue.find(4)
    assert_not issue1.reload.watched_by?(jsmith)
    assert_not issue4.reload.watched_by?(jsmith)
    assert page.has_css?('tr#issue-1')
    assert page.has_css?('tr#issue-4')
    find('tr#issue-1 input[type=checkbox]').click
    find('tr#issue-4 input[type=checkbox]').click
    find('tr#issue-1 td.updated_on').right_click
    assert page.has_css?('#context-menu .issue-bulk-watcher.icon-fav-off')
    assert_difference 'Watcher.count', 2 do
      within('#context-menu') do
        find_link('Watch').hover.click
      end
      # wait for ajax response
      assert page.has_css?('#context-menu .issue-bulk-watcher.icon-fav')
      assert page.has_css?('tr#issue-1')
      assert page.has_css?('tr#issue-4')
    end
    assert issue1.reload.watched_by?(jsmith)
    assert issue4.reload.watched_by?(jsmith)
  end

  def test_bulk_update_issues
    log_user('jsmith', 'jsmith')
    visit '/issues'
    issue1 = Issue.find(1)
    issue4 = Issue.find(4)
    assert_equal 1, issue1.reload.status.id
    assert_equal 1, issue4.reload.status.id
    assert page.has_css?('tr#issue-1')
    assert page.has_css?('tr#issue-4')
    find('tr#issue-1 input[type=checkbox]').click
    find('tr#issue-4 input[type=checkbox]').click
    find('tr#issue-1 td.updated_on').right_click
    within('#context-menu') do
      click_link 'Status'
      click_link 'Closed'
    end
    assert page.has_css?('#flash_notice')
    assert_equal 5, issue1.reload.status.id
    assert_equal 5, issue4.reload.status.id
  end

  def test_bulk_edit
    log_user('jsmith', 'jsmith')
    visit '/issues'
    issue1 = Issue.find(1)
    issue4 = Issue.find(4)
    assert_equal 1, issue1.reload.status.id
    assert_equal 1, issue4.reload.status.id
    assert page.has_css?('tr#issue-1')
    assert page.has_css?('tr#issue-4')
    find('tr#issue-1 input[type=checkbox]').click
    find('tr#issue-4 input[type=checkbox]').click
    find('tr#issue-1 td.updated_on').right_click
    within('#context-menu') do
      click_link 'Bulk edit'
    end
    assert_current_path '/issues/bulk_edit', :ignore_query => true
    submit_buttons = page.all('input[type=submit]')
    assert_equal 1, submit_buttons.size
    assert_equal 'Submit', submit_buttons[0].value

    page.find('#issue_status_id').select('Assigned')
    assert_no_difference 'Issue.count' do
      click_button('commit')
      # wait for ajax response
      assert page.has_css?('#flash_notice')
      assert_current_path '/issues', :ignore_query => true
    end
    assert_equal 2, issue1.reload.status.id
    assert_equal 2, issue4.reload.status.id

    assert page.has_css?('tr#issue-1')
    assert page.has_css?('tr#issue-4')
    find('tr#issue-1 input[type=checkbox]').click
    find('tr#issue-4 input[type=checkbox]').click
    find('tr#issue-1 td.updated_on').right_click
    within('#context-menu') do
      click_link 'Bulk edit'
    end
    assert_current_path '/issues/bulk_edit', :ignore_query => true
    submit_buttons = page.all('input[type=submit]')
    assert_equal 1, submit_buttons.size
    assert_equal 'Submit', submit_buttons[0].value

    page.find('#issue_project_id').select('OnlineStore')
    # wait for ajax response
    assert page.has_select?('issue_project_id', selected: 'OnlineStore')

    assert_selector 'input[type=submit]', count: 2
    submit_buttons = page.all('input[type=submit]')
    assert_equal 'Move', submit_buttons[0].value
    assert_equal 'Move and follow', submit_buttons[1].value

    page.find('#issue_status_id').select('Feedback')
    assert_no_difference 'Issue.count' do
      click_button('follow')
      # wait for ajax response
      assert page.has_css?('#flash_notice')
      assert_current_path '/projects/onlinestore/issues', :ignore_query => true
    end

    issue1.reload
    issue4.reload
    assert_equal 2, issue1.project.id
    assert_equal 4, issue1.status.id
    assert_equal 2, issue4.project.id
    assert_equal 4, issue4.status.id
  end

  def test_bulk_copy
    log_user('jsmith', 'jsmith')
    visit '/issues'
    assert page.has_css?('tr#issue-1')
    assert page.has_css?('tr#issue-4')
    find('tr#issue-1 input[type=checkbox]').click
    find('tr#issue-4 input[type=checkbox]').click
    find('tr#issue-1 td.updated_on').right_click
    within('#context-menu') do
      click_link 'Copy'
    end
    assert_current_path '/issues/bulk_edit', :ignore_query => true
    submit_buttons = page.all('input[type=submit]')
    assert_equal 'Copy', submit_buttons[0].value

    page.find('#issue_priority_id').select('Low')
    assert_difference 'Issue.count', 2 do
      submit_buttons[0].click
      # wait for ajax response
      assert page.has_css?('#flash_notice')
      assert_current_path '/issues', :ignore_query => true
    end

    copies = Issue.order('id DESC').limit(2)
    assert_equal 4, copies[0].priority.id
    assert_equal 4, copies[1].priority.id

    assert page.has_css?('tr#issue-1')
    assert page.has_css?('tr#issue-4')
    find('tr#issue-1 input[type=checkbox]').click
    find('tr#issue-4 input[type=checkbox]').click
    find('tr#issue-1 td.updated_on').right_click
    within('#context-menu') do
      click_link 'Copy'
    end
    assert_current_path '/issues/bulk_edit', :ignore_query => true
    submit_buttons = page.all('input[type=submit]')
    assert_equal 'Copy', submit_buttons[0].value

    page.find('#issue_project_id').select('OnlineStore')
    # Verify that the target version field has been rewritten by the OnlineStore project settings
    # and wait for the project change to complete.
    assert_select 'issue_fixed_version_id', options: ['(No change)', 'none', 'Alpha', 'Systemwide visible version']

    assert_selector 'input[type=submit]', count: 2
    submit_buttons = page.all('input[type=submit]')

    assert_equal 'Copy', submit_buttons[0].value
    assert_equal 'Copy and follow', submit_buttons[1].value
    page.find('#issue_priority_id').select('High')
    assert_difference 'Issue.count', 2 do
      submit_buttons[1].click
      # wait for ajax response
      assert page.has_css?('#flash_notice')
      assert_current_path '/projects/onlinestore/issues', :ignore_query => true
    end

    copies = Issue.order('id DESC').limit(2)
    assert_equal 2, copies[0].project.id
    assert_equal 6, copies[0].priority.id
    assert_equal 2, copies[1].project.id
    assert_equal 6, copies[1].priority.id
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
    assert page.first('#journal-2-notes').has_content?('Some notes with Redmine links')
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

    assert page.first('#journal-2-notes').has_content?('Updated notes')
    assert_equal 'Updated notes', Journal.find(2).notes
  end

  def test_index_as_csv_should_reflect_sort
    log_user('admin', 'admin')

    visit '/issues'
    # Sort issues by subject
    click_on 'Subject'
    click_on 'CSV'
    click_on 'Export'

    csv = CSV.read(downloaded_file("issues.csv"))
    subject_index = csv.shift.index('Subject')
    subjects = csv.pluck(subject_index)
    assert_equal subjects.sort, subjects
  end

  def test_issue_trackers_description_should_select_tracker
    log_user('admin', 'admin')

    visit '/issues/1'
    page.driver.execute_script('$.fx.off = true;')
    page.first(:link, 'Edit').click
    page.click_link('View all trackers description')
    assert page.has_css?('#trackers_description')
    within('#trackers_description') do
      click_link('Feature')
    end

    assert !page.has_css?('#trackers_description')
    assert_equal "2", page.find('select#issue_tracker_id').value
  end

  def test_edit_should_allow_adding_multiple_relations_from_autocomplete
    log_user('admin', 'admin')

    visit '/issues/1'
    page.find('#relations .contextual a').click
    page.fill_in 'relation[issue_to_id]', :with => 'issue'

    within('ul.ui-autocomplete') do
      assert page.has_text? 'Bug #12: Closed issue on a locked version'
      assert page.has_text? 'Bug #11: Closed issue on a closed version'

      first('li.ui-menu-item').click
    end
    assert_equal '12, ', find('#relation_issue_to_id').value

    find('#relation_issue_to_id').click.send_keys('issue due')
    within('ul.ui-autocomplete') do
      assert page.has_text? 'Bug #7: Issue due today'

      find('li.ui-menu-item').click
    end
    assert_equal '12, 7, ', find('#relation_issue_to_id').value

    find('#relations').click_button('Add')

    within('#relations table.issues') do
      assert page.has_text? 'Related to Bug #12'
      assert page.has_text? 'Related to Bug #7'
    end
  end

  def test_update_issue_form_should_include_time_entry_form_only_for_users_with_permission
    log_user('jsmith', 'jsmith')

    visit '/issues/2'
    page.first(:link, 'Edit').click

    # assert log time form exits for user with required permissions on the current project
    assert page.has_css?('#log_time')

    # Change project to trigger an update on issue form
    page.find('#issue_project_id').select('» Private child of eCookbook')
    wait_for_ajax

    # assert log time form does not exist anymore for user without required permissions on the new project
    assert page.has_no_css?('#log_time')
  end

  def test_update_issue_form_should_include_add_notes_form_only_for_users_with_permission
    log_user('jsmith', 'jsmith')

    visit '/issues/2'
    page.first(:link, 'Edit').click

    # assert add notes form exits for user with required permissions on the current project
    assert page.has_css?('#add_notes')

    # remove add issue notes permission from Manager role
    Role.find_by_name('Manager').remove_permission! :add_issue_notes

    # Change project to trigger an update on issue form
    page.find('#issue_project_id').select('» Private child of eCookbook')
    wait_for_ajax

    # assert add notes form does not exist anymore for user without required permissions on the new project
    assert page.has_no_css?('#add_notes')
  end
end
