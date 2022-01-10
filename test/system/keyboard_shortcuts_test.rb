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
           :workflows

  def test_keyboard_shortcuts_to_switch_edit_preview_tabs
    log_user('jsmith', 'jsmith')
    visit 'issues/new'

    fill_in 'Description', :with => 'new issue description'

    # Switch to preview using control + shift + p
    find('#issue_description').click.send_keys([:control, :shift, 'p'])
    find 'div.wiki-preview', :visible => true, :text => 'new issue description'

    # Switch to edit using control + shift + p
    page.find('body').send_keys([:control, :shift, 'p'])
    find 'div.wiki-preview', :visible => false
    find 'textarea.wiki-edit', :visible => true

    # Switch back to preview using command + shift + p
    find('#issue_description').click.send_keys([:command, :shift, 'p'])
    find 'div.wiki-preview', :visible => true, :text => 'new issue description'

    # Switch to edit using control + shift + p
    page.find('body').send_keys([:command, :shift, 'p'])
    find 'div.wiki-preview', :visible => false
    find 'textarea.wiki-edit', :visible => true
  end

  def test_keyboard_shortcuts_should_switch_to_edit_tab_the_last_previewed_tab
    log_user('jsmith', 'jsmith')
    visit 'issues/1/edit'

    page.first(:link, 'Edit').click
    # Preview issue description by clicking the Preview tab
    page.find('#issue_description_and_toolbar').click_link('Preview')
    find 'div#preview_issue_description', :visible => true

    # Preview issue notes by clicking the Preview tab
    page.find('fieldset:nth-child(3)').click_link('Preview')
    find 'div#preview_issue_notes', :visible => true

    page.find('body').send_keys([:command, :shift, 'p'])
    find 'textarea#issue_notes', :visible => true
    find 'div#preview_issue_notes', :visible => false
  end

  def test_keyboard_shortcuts_for_wiki_toolbar_buttons_using_textile
    with_settings :text_formatting => 'textile' do
      log_user('jsmith', 'jsmith')
      visit 'issues/new'

      find('#issue_description').click.send_keys([modifier_key, 'b'])
      assert_equal '**', find('#issue_description').value

      # Clear textarea value
      fill_in 'Description', :with => ''
      find('#issue_description').send_keys([modifier_key, 'u'])
      assert_equal '++', find('#issue_description').value

      # Clear textarea value
      fill_in 'Description', :with => ''
      find('#issue_description').send_keys([modifier_key, 'i'])
      assert_equal '__', find('#issue_description').value
    end
  end

  def test_keyboard_shortcuts_for_wiki_toolbar_buttons_using_markdown
    with_settings :text_formatting => 'markdown' do
      log_user('jsmith', 'jsmith')
      visit 'issues/new'

      find('#issue_description').click.send_keys([modifier_key, 'b'])
      assert_equal '****', find('#issue_description').value

      # Clear textarea value
      fill_in 'Description', :with => ''
      find('#issue_description').send_keys([modifier_key, 'u'])
      assert_equal '__', find('#issue_description').value

      # Clear textarea value
      fill_in 'Description', :with => ''
      find('#issue_description').send_keys([modifier_key, 'i'])
      assert_equal '**', find('#issue_description').value
    end
  end

  def test_keyboard_shortcuts_keys_should_be_shown_in_button_title
    log_user('jsmith', 'jsmith')
    visit 'issues/new'

    within('.jstBlock .jstElements') do
      assert_equal "Strong (#{modifier_key_title}B)", find('button.jstb_strong')['title']
      assert_equal "Italic (#{modifier_key_title}I)", find('button.jstb_em')['title']
      assert_equal "Underline (#{modifier_key_title}U)", find('button.jstb_ins')['title']
    end
  end

  private

  def modifier_key
    modifier = osx? ? "command" : "control"
    modifier.to_sym
  end

  def modifier_key_title
    osx? ? "⌘" : "Ctrl+"
  end
end
