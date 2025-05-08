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

class IssuesReplyTest < ApplicationSystemTestCase
  def test_reply_to_issue
    with_text_formatting 'common_mark' do
      within '.issue.details' do
        click_link 'Quote'
      end

      # Select the other than the issue description element.
      page.execute_script <<-JS
        const range = document.createRange();
        // Select "Description" text.
        range.selectNodeContents(document.querySelector('.description > p'))

        window.getSelection().addRange(range);
      JS

      assert_field 'issue_notes', with: <<~TEXT
        John Smith wrote:
        > Unable to print recipes

      TEXT
      assert_selector :css, '#issue_notes:focus'
    end
  end

  def test_reply_to_note
    with_text_formatting 'textile' do
      within '#change-1' do
        click_link 'Quote'
      end

      assert_field 'issue_notes', with: <<~TEXT
        Redmine Admin wrote in #note-1:
        > Journal notes

      TEXT
      assert_selector :css, '#issue_notes:focus'
    end
  end

  def test_reply_to_issue_with_partial_quote
    with_text_formatting 'common_mark' do
      assert_text 'Unable to print recipes'

      # Select only the "print" text from the text "Unable to print recipes" in the description.
      page.execute_script <<-JS
        const range = document.createRange();
        const wiki = document.querySelector('#issue_description_wiki > p').childNodes[0];
        range.setStart(wiki, 10);
        range.setEnd(wiki, 15);

        window.getSelection().addRange(range);
      JS

      within '.issue.details' do
        click_link 'Quote'
      end

      assert_field 'issue_notes', with: <<~TEXT
        John Smith wrote:
        > print

      TEXT
      assert_selector :css, '#issue_notes:focus'
    end
  end

  def test_reply_to_note_with_partial_quote
    with_text_formatting 'textile' do
      assert_text 'Journal notes'

      # Select the entire details of the note#1 and the part of the note#1's text.
      page.execute_script <<-JS
        const range = document.createRange();
        range.setStartBefore(document.querySelector('#change-1 .details'));
        // Select only the text "Journal" from the text "Journal notes" in the note-1.
        range.setEnd(document.querySelector('#change-1 .wiki > p').childNodes[0], 7);

        window.getSelection().addRange(range);
      JS

      within '#change-1' do
        click_link 'Quote'
      end

      assert_field 'issue_notes', with: <<~TEXT
        Redmine Admin wrote in #note-1:
        > Journal

      TEXT
      assert_selector :css, '#issue_notes:focus'
    end
  end

  def test_partial_quotes_should_be_quoted_in_plain_text_when_text_format_is_textile
    issues(:issues_001).update!(description: <<~DESC)
      # "Redmine":https://redmine.org is
      # a *flexible* project management
      # web application.
    DESC

    with_text_formatting 'textile' do
      assert_text /a flexible project management/

      # Select the entire description of the issue.
      page.execute_script <<-JS
        const range = document.createRange();
        range.selectNodeContents(document.querySelector('#issue_description_wiki'))
        window.getSelection().addRange(range);
      JS

      within '.issue.details' do
        click_link 'Quote'
      end

      expected_value = [
        'John Smith wrote:',
        '> Redmine is',
        '> a flexible project management',
        '> web application.',
        '',
        ''
      ]
      assert_equal expected_value.join("\n"), find_field('issue_notes').value
    end
  end

  def test_partial_quotes_should_be_quoted_in_common_mark_format_when_text_format_is_common_mark
    issues(:issues_001).update!(description: <<~DESC)
      # Title1
      [Redmine](https://redmine.org) is a **flexible** project management web application.

      ## Title2
      * List1
        * List1-1
      * List2

      1. Number1
      1. Number2

      ### Title3
      ```ruby
      puts "Hello, world!"
      ```
      ```
      $ bin/rails db:migrate
      ```

      | Subject1 | Subject2 |
      | -------- | -------- |
      | ~~cell1~~| **cell2**|

      * [ ] Checklist1
      * [x] Checklist2

      [[WikiPage]]
      Issue #14
      Issue ##2

      Redmine is `a flexible` project management

      web application.
    DESC

    with_text_formatting 'common_mark' do
      assert_text /Title1/

      # Select the entire description of the issue.
      page.execute_script <<-JS
        const range = document.createRange();
        range.selectNodeContents(document.querySelector('#issue_description_wiki'))
        window.getSelection().addRange(range);
      JS

      within '.issue.details' do
        click_link 'Quote'
      end

      expected_value = [
        'John Smith wrote:',
        '> # Title1',
        '> ',
        '> [Redmine](https://redmine.org) is a **flexible** project management web application.',
        '> ',
        '> ## Title2',
        '> ',
        '> *   List1',
        '>     *   List1-1',
        '> *   List2',
        '> ',
        '> 1.  Number1',
        '> 2.  Number2',
        '> ',
        '> ### Title3',
        '> ',
        '> ```ruby',
        '> puts "Hello, world!"',
        '> ```',
        '> ',
        '> ```',
        '> $ bin/rails db:migrate',
        '> ```',
        '> ',
        '> Subject1 Subject2',
        '> ~~cell1~~ **cell2**',
        '> ',
        '> *   [ ] Checklist1',
        '> *   [x] Checklist2',
        '> ',
        '> [WikiPage](/projects/ecookbook/wiki/WikiPage)  ',
        '> Issue [#14](/issues/14 "Bug: Private issue on public project (New)")  ',
        '> Issue [Feature request #2: Add ingredients categories](/issues/2 "Status: Assigned")',
        '> ',
        '> Redmine is `a flexible` project management',
        '> ',
        '> web application.',
        '',
        ''
      ]
      assert_equal expected_value.join("\n"), find_field('issue_notes').value
    end
  end

  private

  def with_text_formatting(format)
    with_settings text_formatting: format do
      log_user('jsmith', 'jsmith')
      visit '/issues/1'

      yield
    end
  end
end
