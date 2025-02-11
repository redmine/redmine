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

class InlineAutocompleteSystemTest < ApplicationSystemTestCase
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

  def test_inline_autocomplete_for_issues_with_double_hash_keep_syntax
    log_user('admin', 'admin')
    visit 'projects/ecookbook/issues/new'

    fill_in 'Description', :with => '##Cl'

    assert_selector '.tribute-container li', count: 3
    within('.tribute-container') do
      assert page.has_text? 'Bug #12: Closed issue on a locked version'
      assert page.has_text? 'Bug #11: Closed issue on a closed version'
      assert page.has_text? 'Bug #8: Closed issue'

      first('li').click
    end

    assert_equal '##12 ', find('#issue_description').value
  end

  def test_inline_autocomplete_filters_autocomplete_items
    log_user('jsmith', 'jsmith')
    visit 'issues/new'

    fill_in 'Description', :with => '#Cl'

    assert_selector '.tribute-container li', count: 3
    within('.tribute-container') do
      assert page.has_text? 'Bug #12: Closed issue on a locked version'
      assert page.has_text? 'Bug #11: Closed issue on a closed version'
      assert page.has_text? 'Bug #8: Closed issue'
    end
  end

  def test_inline_autocomplete_on_issue_edit_description_should_show_autocomplete
    log_user('jsmith', 'jsmith')
    visit 'issues/1/edit'

    within('#issue-form') do
      click_link('Edit', match: :first)
      fill_in 'Description', :with => '#'
    end

    assert_selector '.tribute-container li', minimum: 1
  end

  def test_inline_autocomplete_on_issue_edit_notes_should_show_autocomplete
    log_user('jsmith', 'jsmith')
    visit 'issues/1/edit'

    # Prevent random fails because the element is not yet enabled
    find('#issue_notes').click
    fill_in 'issue[notes]', :with => '#'

    assert_selector '.tribute-container li', minimum: 1
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

    assert_selector '.tribute-container li', minimum: 1
  end

  def test_inline_autocomplete_on_wiki_should_show_autocomplete
    log_user('jsmith', 'jsmith')
    visit 'projects/ecookbook/wiki/CookBook_documentation/edit'

    # Prevent random fails because the element is not yet enabled
    find('.wiki-edit').click
    fill_in 'content[text]', :with => '#'

    assert_selector '.tribute-container li', minimum: 1
  end

  def test_inline_autocomplete_on_news_description_should_show_autocomplete
    log_user('jsmith', 'jsmith')
    visit 'projects/ecookbook/news'

    click_link 'Add news'

    # Prevent random fails because the element is not yet enabled
    find('.wiki-edit').click
    fill_in 'Description', :with => '#'

    assert_selector '.tribute-container li', minimum: 1
  end

  def test_inline_autocomplete_on_new_message_description_should_show_autocomplete
    log_user('jsmith', 'jsmith')
    visit 'projects/ecookbook/boards/1'

    click_link 'New message'

    # Prevent random fails because the element is not yet enabled
    find('.wiki-edit').click
    fill_in 'message[content]', :with => '#'

    assert_selector '.tribute-container li', minimum: 1
  end

  def test_inline_autocompletion_of_wiki_page_links
    log_user('jsmith', 'jsmith')
    visit 'issues/new'

    fill_in 'Description', :with => '[['

    within('.tribute-container') do
      assert page.has_text? 'Child_1_1'
      assert page.has_text? 'Page_with_sections'
    end

    fill_in 'Description', :with => '[[p'

    assert_selector '.tribute-container li', count: 3
    within('.tribute-container') do
      assert page.has_text? 'Page_with_sections'
      assert page.has_text? 'Page_with_an_inline_image'
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

    fill_in 'Description', :with => '#Th'

    assert_selector '.tribute-container li', count: 1
    within('.tribute-container') do
      assert page.has_text? "Bug ##{issue.id}: This issue has a <select> element"
    end
  end

  def test_inline_autocomplete_for_users_should_work_after_status_change
    log_user('jsmith', 'jsmith')
    visit '/issues/1/edit'

    find('#issue_notes').click
    fill_in 'issue[notes]', :with => '@'

    assert_selector '.tribute-container li', minimum: 1

    page.find('#issue_status_id').select('Feedback')

    find('#issue_notes').click
    fill_in 'issue[notes]', :with => '@j'

    assert_selector '.tribute-container li', count: 1
    within('.tribute-container') do
      assert page.has_text? 'John Smith'
    end
  end

  def test_inline_autocomplete_for_users_on_issues_bulk_edit_show_autocomplete
    log_user('jsmith', 'jsmith')
    visit '/issues/bulk_edit?ids[]=1&ids[]=2'

    find('#notes').click
    fill_in 'notes', :with => '@j'

    assert_selector '.tribute-container li', count: 1
    within('.tribute-container') do
      assert page.has_text? 'John Smith'
      first('li').click
    end

    assert_equal '@jsmith ', find('#notes').value
  end

  def test_inline_autocomplete_for_users_on_issues_without_edit_issue_permission
    role_developer = Role.find(2)
    role_developer.remove_permission!(:edit_issues)
    role_developer.add_permission!(:add_issue_watchers)

    log_user('jsmith', 'jsmith')
    visit '/issues/4/edit'

    find('#issue_notes').click
    fill_in 'issue[notes]', :with => '@'

    within('.tribute-container') do
      assert page.has_text? 'John Smith'
      first('li').click
    end

    assert_equal '@jsmith ', find('#issue_notes').value
  end
end
