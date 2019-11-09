# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2019  Jean-Philippe Lang
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

class Redmine::WikiFormatting::MarkdownHtmlParserTest < ActiveSupport::TestCase

  def setup
    @parser = Redmine::WikiFormatting::Markdown::HtmlParser
  end

  def test_should_convert_tags
    assert_equal 'A **simple** html snippet.',
      @parser.to_text('<p>A <b>simple</b> html snippet.</p>')

    assert_equal 'foo [bar](http://example.com/) baz',
      @parser.to_text('foo<a href="http://example.com/">bar</a>baz')

    assert_equal 'foo http://example.com/ baz',
      @parser.to_text('foo<a href="http://example.com/"></a>baz')

    assert_equal 'foobarbaz',
      @parser.to_text('foo<a name="Header-one">bar</a>baz')

    assert_equal 'foobaz',
      @parser.to_text('foo<a name="Header-one"/>baz')
  end

  def test_html_tables_conversion
    assert_equal "*th1*\n*th2*\n\ntd1\ntd2",
      @parser.to_text('<table><tr><th>th1</th><th>th2</th></tr><tr><td>td1</td><td>td2</td></tr></table>')
  end
end
