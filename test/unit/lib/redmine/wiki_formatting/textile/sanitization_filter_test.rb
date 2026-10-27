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

require_relative '../../../../../test_helper'

class Redmine::WikiFormatting::Textile::SanitizationFilterTest < ActiveSupport::TestCase
  def filter(html)
    fragment = Redmine::WikiFormatting::HtmlParser.parse(html)
    sanitizer = Redmine::WikiFormatting::Textile::SanitizationFilter.new
    sanitizer.call(fragment)
    fragment.to_s
  end

  def test_should_filter_tags
    input = %(<script>alert(1)</script><iframe src="https://example.com/"></iframe><input type="text"> <b>foo</b>)
    assert_equal %( <b>foo</b>), filter(input)
  end

  def test_should_sanitize_attributes
    input = %(<img src="foo.png" onerror="alert(1)"> <a href="foo" onclick="alert(1)">link</a>)
    assert_equal %(<img src="foo.png"> <a href="foo">link</a>), filter(input)
  end

  def test_should_remove_links_with_unsafe_scheme
    input = %(<a href="javascript:alert(1)">link</a>)
    assert_equal %(<a>link</a>), filter(input)
  end

  def test_should_allow_classes_and_ids_generated_by_textile
    [
      %(<p class="wiki-class-foo wiki-class-bar" id="wiki-id-baz">foo</p>),
      %(<a class="external" href="https://example.com/">foo</a>),
      %(<a class="email" href="mailto:foo@example.com">foo</a>),
      %(<p id="fn1" class="footnote"><sup>1</sup> foo</p>),
      %(<pre><code class="ruby">foo</code></pre>),
    ].each do |input|
      assert_equal input, filter(input)
    end
  end

  def test_should_remove_other_classes_and_ids
    input = %(<p class="wiki-class-foo flash error" id="main-menu">foo</p>)
    assert_equal %(<p class="wiki-class-foo">foo</p>), filter(input)
  end

  def test_should_allow_styles_generated_by_textile
    [
      %(<p style="vertical-align:top;">foo</p>),
      %(<p style="background:#fdd;">foo</p>),
      %(<p style="border-top-left-radius: 10px 5px;">foo</p>),
    ].each do |input|
      assert_equal input, filter(input)
    end
  end
end
