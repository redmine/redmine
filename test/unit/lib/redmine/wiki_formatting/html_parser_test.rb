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

require File.expand_path('../../../../../test_helper', __FILE__)

class Redmine::WikiFormatting::HtmlParserTest < ActiveSupport::TestCase

  def setup
    @parser = Redmine::WikiFormatting::HtmlParser
  end

  def test_convert_line_breaks
    assert_equal "A html snippet with\na new line.",
      @parser.to_text('<p>A html snippet with<br>a new line.</p>')
  end

  def test_should_remove_style_tags_from_body
    assert_equal "Text",
      @parser.to_text('<html><body><style>body {font-size: 0.8em;}</style>Text</body></html>')
  end
end
