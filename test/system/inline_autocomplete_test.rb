# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2022  Jean-Philippe Lang
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

class InlineAutocompleteSystemTest < ApplicationSystemTestCase
  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles,
           :trackers, :projects_trackers, :enabled_modules, :issue_statuses, :issues,
           :enumerations, :custom_fields, :custom_values, :custom_fields_trackers,
           :watchers, :journals, :journal_details, :versions,
           :workflows, :wikis, :wiki_pages, :wiki_contents, :wiki_content_versions

  def test_inline_autocomplete_for_issues
    log_user('jsmith', 'jsmith')
    visit 'issues/new'

    fill_in 'Description', :with => '#'

    within('.tribute-container') do
      assert page.has_text? 'Bug #12: Closed issue on a locked version'
      assert page.has_text? 'Bug #1: Cannot print recipes'

      first('li').click
    end

    assert_equal '#12 ', find('#issue_description').value
  end

  def test_inline_autocomplete_filters_autocomplete_items
    log_user('jsmith', 'jsmith')
    visit 'issues/new'

    fill_in 'Description', :with => '#Closed'

    within('.tribute-container') do
      assert page.has_text? 'Bug #12: Closed issue on a locked version'
      assert page.has_text? 'Bug #11: Closed issue on a closed version'
      assert_not page.has_text? 'Bug #1: Cannot print recipes'
    end
  end

  def test_inline_autocomplete_on_issue_edit_description_should_show_autocomplete
    log_user('jsmith', 'jsmith')
    visit 'issues/1/edit'

    within('#issue-form') do
      click_link('Edit', match: :first)
      fill_in 'Description', :with => '#'
    end

    page.has_css?('.tribute-container li', minimum: 1)
  end

  def test_inline_autocomplete_on_issue_edit_notes_should_show_autocomplete
    log_user('jsmith', 'jsmith')
    visit 'issues/1/edit'

    # Prevent random fails because the element is not yet enabled
    find('#issue_notes').click
    fill_in 'issue[notes]', :with => '#'

    page.has_css?('.tribute-container li', minimum: 1)
  end

  def test_inline_autocomplete_on_issue_custom_field_with_full_text_formatting_should_show_autocomplete
    IssueCustomField.create!(
      :name => 'Full width field',
      :field_format => 'text', :full_width_layout => '1',
      :tracker_ids => [1], :is_for_all => true, :text_formatting => 'full'
    )

    log_user('jsmith', 'jsmith')
    visit 'issues/new'

    fill_in 'Full width field', :with => '#'

    page.has_css?('.tribute-container li', minimum: 1)
  end

  def test_inline_autocomplete_on_wiki_should_show_autocomplete
    log_user('jsmith', 'jsmith')
    visit 'projects/ecookbook/wiki/CookBook_documentation/edit'

    # Prevent random fails because the element is not yet enabled
    find('.wiki-edit').click
    fill_in 'content[text]', :with => '#'

    page.has_css?('.tribute-container li', minimum: 1)
  end

  def test_inline_autocomplete_on_news_description_should_show_autocomplete
    log_user('jsmith', 'jsmith')
    visit 'projects/ecookbook/news'

    click_link 'Add news'

    # Prevent random fails because the element is not yet enabled
    find('.wiki-edit').click
    fill_in 'Description', :with => '#'

    page.has_css?('.tribute-container li', minimum: 1)
  end

  def test_inline_autocomplete_on_new_message_description_should_show_autocomplete
    log_user('jsmith', 'jsmith')
    visit 'projects/ecookbook/boards/1'

    click_link 'New message'

    # Prevent random fails because the element is not yet enabled
    find('.wiki-edit').click
    fill_in 'message[content]', :with => '#'

    page.has_css?('.tribute-container li', minimum: 1)
  end

  def test_inline_autocompletion_of_wiki_page_links
    log_user('jsmith', 'jsmith')
    visit 'issues/new'

    fill_in 'Description', :with => '[['

    within('.tribute-container') do
      assert page.has_text? 'Child_1_1'
      assert page.has_text? 'Page_with_sections'
    end

    fill_in 'Description', :with => '[[page'
    within('.tribute-container') do
      assert page.has_text? 'Page_with_sections'
      assert page.has_text? 'Another_page'
      assert_not page.has_text? 'Child_1_1'

      first('li').click
    end
    assert_equal '[[Page_with_sections]] ', find('#issue_description').value
  end

  def test_inline_autocomplete_for_issues_should_escape_html_elements
    issue = Issue.generate!(subject: 'This issue has a <select> element', project_id: 1, tracker_id: 1)

    log_user('jsmith', 'jsmith')
    visit 'projects/1/issues/new'

    fill_in 'Description', :with => '#This'

    within('.tribute-container') do
      assert page.has_text? "Bug ##{issue.id}: This issue has a <select> element"
    end
  end

  def test_inline_autocomplete_for_users_should_work_after_status_change
    log_user('jsmith', 'jsmith')
    visit '/issues/1/edit'

    find('#issue_notes').click
    fill_in 'issue[notes]', :with => '@lopper'

    within('.tribute-container') do
      assert page.has_text? "Dave Lopper"
    end

    page.find('#issue_status_id').select('Feedback')

    find('#issue_notes').click
    fill_in 'issue[notes]', :with => '@lopper'

    within('.tribute-container') do
      assert page.has_text? "Dave Lopper"
    end

  end

  def test_inline_autocomplete_for_users_on_issues_bulk_edit_show_autocomplete
    log_user('jsmith', 'jsmith')
    visit '/issues/bulk_edit?ids[]=1&ids[]=2'

    find('#notes').click
    fill_in 'notes', :with => '@lopper'

    within('.tribute-container') do
      assert page.has_text? 'Dave Lopper'
      first('li').click
    end

    assert_equal '@dlopper ', find('#notes').value
  end
end
