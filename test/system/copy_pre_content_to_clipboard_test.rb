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
class CopyPreContentToClipboardSystemTest < ApplicationSystemTestCase
  def test_copy_issue_pre_content_to_clipboard_if_common_mark
    issue = Issue.find(1)
    issue.update(description: "```\ntest\ncommon mark\n```")
    assert_copied_pre_content_matches(issue_id: issue.id, expected_value: "test\ncommon mark")
  end

  def test_copy_issue_code_content_to_clipboard_if_common_mark
    issue = Issue.find(1)
    issue.update(description: "```ruby\nputs 'Hello, World.'\ncommon mark\n```")
    assert_copied_pre_content_matches(issue_id: issue.id, expected_value: "puts 'Hello, World.'\ncommon mark")
  end

  def test_copy_issue_pre_content_to_clipboard_if_textile
    issue = Issue.find(1)
    issue.update(description: "<pre>\ntest\ntextile\n</pre>")
    with_settings text_formatting: :textile do
      assert_copied_pre_content_matches(issue_id: issue.id, expected_value: "test\ntextile")
    end
  end

  def test_copy_issue_code_content_to_clipboard_if_textile
    issue = Issue.find(1)
    issue.update(description: "<pre><code class=\"ruby\">\nputs 'Hello, World.'\ntextile\n</code></pre>")
    with_settings text_formatting: :textile do
      assert_copied_pre_content_matches(issue_id: issue.id, expected_value: "puts 'Hello, World.'\ntextile")
    end
  end

  private

  def modifier_key
    modifier = osx? ? 'command' : 'control'
    modifier.to_sym
  end

  def assert_copied_pre_content_matches(issue_id:, expected_value:)
    visit "/issues/#{issue_id}"
    # A button appears when hovering over the <pre> tag
    find("#issue_description_wiki div.pre-wrapper:first-of-type").hover
    assert_selector('#issue_description_wiki div.pre-wrapper:first-of-type .copy-pre-content-link')

    # Copy pre content to Clipboard
    find("#issue_description_wiki div.pre-wrapper:first-of-type .copy-pre-content-link").click

    # Paste the value copied to the clipboard into the textarea to get and test
    first('.icon-edit').click
    find('textarea#issue_notes').set('')
    find('textarea#issue_notes').send_keys([modifier_key, 'v'])
    assert_equal find('textarea#issue_notes').value, expected_value
  end
end
