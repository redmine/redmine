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

class TablePasteSystemTest < ApplicationSystemTestCase
  HTML_TABLE = <<~'HTML'
    <table>
      <tr><th>Item</th><th>Notes</th></tr>
      <tr><td>Redmine 6.1</td><td>Supports &lt;wiki&gt; tags</td></tr>
      <tr><td>Multi-line</td><td>First line<br>Second line | escaped</td></tr>
      <tr><td>Path value</td><td>C:\Temp\redmine &amp; logs</td></tr>
    </table>
  HTML

  def test_paste_html_table_as_commonmark_table_in_issue_description
    with_settings text_formatting: 'common_mark' do
      log_user('jsmith', 'jsmith')
      visit '/projects/ecookbook/issues/new'

      result = dispatch_paste(find('#issue_description'), html: HTML_TABLE)

      assert_equal <<~'TEXT', result
        | Item | Notes |
        | -- | -- |
        | Redmine 6.1 | Supports <wiki> tags |
        | Multi-line | First line<br>Second line \| escaped |
        | Path value | C:\Temp\redmine & logs |

      TEXT
    end
  end

  def test_paste_html_table_as_textile_table_in_wiki_edit
    with_settings text_formatting: 'textile' do
      log_user('jsmith', 'jsmith')
      visit '/projects/ecookbook/wiki/CookBook_documentation/edit'

      result = dispatch_paste(find('#content_text'), html: HTML_TABLE)

      assert_equal <<~'TEXT', result
        |_. Item |_. Notes |
        | Redmine 6.1 | Supports <wiki> tags |
        | Multi-line | First line
        Second line &#124; escaped |
        | Path value | C:\Temp\redmine & logs |

      TEXT
    end
  end

  def test_pastes_only_standalone_html_tables
    with_settings text_formatting: 'common_mark' do
      log_user('jsmith', 'jsmith')
      visit '/projects/ecookbook/issues/new'

      # Pasted content from Excel
      pasted = dispatch_paste(find('#issue_description'), html: <<~HTML)
        <html>
        <head>
        <meta http-equiv=Content-Type content="text/html; charset=utf-8">
        <meta name=ProgId content=Excel.Sheet>
        <style>td {white-space:nowrap;}</style>
        <link rel=File-List href="file:///C:/Temp/clip_filelist.xml">
        </head>
        <body>
        <table><tr><td>Item</td><td>Notes</td></tr><tr><td>Table</td><td>Value</td></tr></table>
        </body>
        </html>
      HTML
      assert_includes pasted, "| Item | Notes |"

      # Pasted content from Google Sheets
      pasted = dispatch_paste(find('#issue_description'), html: <<~HTML)
        <meta><style>td {border: 1px solid #cccccc;}</style>
        <table><tr><td>Item</td><td>Notes</td></tr><tr><td>Table</td><td>Value</td></tr></table>
      HTML
      assert_includes pasted, "| Item | Notes |"

      # Pasted content without a table
      pasted = dispatch_paste(find('#issue_description'), html: '<p>Content</p>')
      assert_equal '', pasted # Handled as a normal paste.

      # Pasted content with a table and other HTML content
      pasted = dispatch_paste(find('#issue_description'), html: <<~HTML)
        <h1>Title</h1><table><tr><td>Item</td><td>Notes</td></tr></table>
      HTML
      assert_equal '', pasted # Handled as a normal paste.

      # Pasted content with multiple tables
      pasted = dispatch_paste(find('#issue_description'), html: <<~HTML)
        <table><tr><td>Item</td><td>Notes</td></tr></table>
        <table><tr><td>Item</td><td>Notes</td></tr></table>
      HTML
      assert_equal '', pasted # Handled as a normal paste.

      # Pasted content with a single table row
      pasted = dispatch_paste(find('#issue_description'), html: <<~HTML)
        <table><tr><td>Item</td><td>Notes</td></tr></table>
      HTML
      assert_equal '', pasted # Handled as a normal paste.
    end
  end

  def test_paste_html_table_strips_unsafe_markup
    with_settings text_formatting: 'common_mark' do
      log_user('jsmith', 'jsmith')
      visit '/projects/ecookbook/issues/new'

      html = <<~HTML
        <table border="1">
          <tr>
            <td>
              probe
              <img
                src="a"
                onerror="window._dom_xss_executed = true">
            </td>
            <td>x</td>
          </tr>
          <tr>
            <td>y</td>
            <td>z</td>
          </tr>
        </table>
      HTML

      result = dispatch_paste(find('#issue_description'), html: html)
      sleep 1

      assert_nil page.evaluate_script('window._dom_xss_executed')
      assert_includes result, '| probe | x |'
      assert_includes result, '| y | z |'
    end
  end

  private

  def dispatch_paste(field, html:)
    page.evaluate_script(<<~JS, field, html)
      ((element, htmlText) => {
        element.value = ''
        element.setSelectionRange(0, 0)

        const clipboardData = {
          getData(type) {
            return type === 'text/html' ? htmlText : ''
          }
        }

        const event = new Event('paste', { bubbles: true, cancelable: true })
        Object.defineProperty(event, 'clipboardData', { value: clipboardData })
        element.dispatchEvent(event)

        return element.value
      })(arguments[0], arguments[1])
    JS
  end
end
