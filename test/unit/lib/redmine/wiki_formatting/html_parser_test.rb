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

require File.expand_path('../../../../../test_helper', __FILE__)

class Redmine::WikiFormatting::HtmlParserTest < ActiveSupport::TestCase
  def setup
    @parser = Redmine::WikiFormatting::HtmlParser
  end

  def test_convert_line_breaks
    assert_equal(
      "A html snippet with\na new line.",
      @parser.to_text('<p>A html snippet with<br>a new line.</p>')
    )
  end

  def test_should_remove_style_tags_from_body
    assert_equal(
      "Text",
      @parser.to_text('<html><body><style>body {font-size: 0.8em;}</style>Text</body></html>')
    )
  end

  def test_should_remove_preceding_whitespaces
    to_test = {
      "<div>  blocks with</div>\n<p>\n  preceding whitespaces\n</p>" => "blocks with\n\npreceding whitespaces",
      "<div>blocks without</div>\n<p>\npreceding whitespaces\n</p>" => "blocks without\n\npreceding whitespaces",
      "<span>  span with</span>\n<span>  preceding whitespaces</span>" => "span with preceding whitespaces",
      "<span>span without</span>\n<span>preceding whitespaces</span>" => "span without preceding whitespaces"
    }
    to_test.each do |html, expected|
      assert_equal expected, @parser.to_text(html)
    end
  end

  def test_should_remove_space_of_beginning_of_line
    str = <<~HTML
      <table>
        <tr>
          <th>th1</th>
          <th>th2</th>
        </tr>
        <tr>
          <td>td1</td>
          <td>td2</td>
        </tr>
      </table>
    HTML
    assert_equal(
      "th1\n\nth2\n\ntd1\n\ntd2",
      @parser.to_text(str)
    )
  end
end
