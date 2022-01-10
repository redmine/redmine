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

require_relative '../application_system_test_case'

class CopyToClipboardSystemTest < ApplicationSystemTestCase
  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles,
           :trackers, :projects_trackers, :enabled_modules, :issue_statuses, :issues,
           :enumerations, :custom_fields, :custom_values, :custom_fields_trackers,
           :watchers, :journals, :journal_details, :versions,
           :workflows, :wikis, :wiki_pages, :wiki_contents, :wiki_content_versions

  def test_copy_issue_url_to_clipboard
    log_user('jsmith', 'jsmith')
    visit 'issues/1'

    # Copy issue url to Clipboard
    first('.contextual span.icon-actions').click
    find('.contextual div.drdn-items a.icon-copy-link').click

    # Paste the value copied to the clipboard into the textarea to get and test
    first('.icon-edit').click
    find('textarea#issue_notes').send_keys([modifier_key, 'v'])
    assert find('textarea#issue_notes').value.end_with?('/issues/1')
  end

  def test_copy_issue_journal_url_to_clipboard
    log_user('jsmith', 'jsmith')
    visit 'issues/1'

    # Copy issue journal url to Clipboard
    first('#note-2 .icon-actions').click
    first('#note-2 div.drdn-items a.icon-copy-link').click

    # Paste the value copied to the clipboard into the textarea to get and test
    first('.icon-edit').click
    find('textarea#issue_notes').send_keys([modifier_key, 'v'])
    assert find('textarea#issue_notes').value.end_with?('/issues/1#note-2')
  end

  private

  def modifier_key
    modifier = osx? ? 'command' : 'control'
    modifier.to_sym
  end
end
