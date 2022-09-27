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

require File.expand_path('../../../../../../test_helper', __FILE__)

if Object.const_defined?(:CommonMarker)
  require 'redmine/wiki_formatting/common_mark/sanitization_filter'

  class Redmine::WikiFormatting::CommonMark::SanitizationFilterTest < ActiveSupport::TestCase
    def filter(html)
      Redmine::WikiFormatting::CommonMark::SanitizationFilter.to_html(html, @options)
    end

    def setup
      @options = { }
    end

    def test_should_filter_tags
      input = %(<textarea>foo</textarea> <blink>dont blink</blink>)
      assert_equal %(foo dont blink), filter(input)
    end

    def test_should_sanitize_attributes
      input = %(<a href="foo" onclick="bar" baz="foo">link</a>)
      assert_equal %(<a href="foo">link</a>), filter(input)
    end

    def test_should_allow_relative_links
      input = %(<a href="foo/bar">foo/bar</a>)
      assert_equal input, filter(input)
    end

    def test_should_support_footnotes
      input = %(<a href="#fn-1" id="fnref-1">foo</a>)
      assert_equal input, filter(input)
      input = %(<ol><li id="fn-1">footnote</li></ol>)
      assert_equal input, filter(input)
    end

    def test_should_remove_invalid_ids
      input = %(<a href="#fn1" id="foo">foo</a>)
      assert_equal %(<a href="#fn1">foo</a>), filter(input)
      input = %(<ol><li id="foo">footnote</li></ol>)
      assert_equal %(<ol><li>footnote</li></ol>), filter(input)
    end

    def test_should_allow_class_on_code_only
      input = %(<p class="foo">bar</p>)
      assert_equal %(<p>bar</p>), filter(input)

      input = %(<code class="language-ruby">foo</code>)
      assert_equal input, filter(input)

      input = %(<code class="foo">foo</code>)
      assert_equal %(<code>foo</code>), filter(input)
    end

    def test_should_allow_links_with_safe_url_schemes
      %w(http https ftp ssh foo).each do |scheme|
        input = %(<a href="#{scheme}://example.org/">foo</a>)
        assert_equal input, filter(input)
      end
    end

    def test_should_allow_mailto_links
      input = %(<a href="mailto:foo@example.org">bar</a>)
      assert_equal input, filter(input)
    end

    def test_should_remove_empty_link
      input = %(<a href="">bar</a>)
      assert_equal %(<a>bar</a>), filter(input)
      input = %(<a href=" ">bar</a>)
      assert_equal %(<a>bar</a>), filter(input)
    end

    # samples taken from the Sanitize test suite
    # rubocop:disable Layout/LineLength
    STRINGS = [
      [
        '<span style="color: #333; background: url(\'https://example.com/evil.svg\')">hello</span>"',
        '<span style="color: #333; ">hello</span>"'
      ],
      [
        '<b>Lo<!-- comment -->rem</b> <a href="pants" title="foo" style="text-decoration: underline;">ipsum</a> <a href="http://foo.com/"><strong>dolor</strong></a> sit<br/>amet <style>.foo { color: #fff; }</style> <script>alert("hello world");</script>',
        '<b>Lorem</b> <a href="pants" title="foo">ipsum</a> <a href="http://foo.com/"><strong>dolor</strong></a> sit<br>amet .foo { color: #fff; } '
      ],
      [
        'Lo<!-- comment -->rem</b> <a href=pants title="foo>ipsum <a href="http://foo.com/"><strong>dolor</a></strong> sit<br/>amet <script>alert("hello world");',
        'Lorem <a href="pants" title="foo&gt;ipsum &lt;a href="><strong>dolor</strong></a> sit<br>amet '
      ],
      [
        '<p>a</p><blockquote>b',
        '<p>a</p><blockquote>b</blockquote>'
      ],
      [
        '<b>Lo<!-- comment -->rem</b> <a href="javascript:pants" title="foo">ipsum</a> <a href="http://foo.com/"><strong>dolor</strong></a> sit<br/>amet <<foo>script>alert("hello world");</script>',
        '<b>Lorem</b> <a title="foo">ipsum</a> <a href="http://foo.com/"><strong>dolor</strong></a> sit<br>amet &lt;script&gt;alert("hello world");'
      ]
    ]
    # rubocop:enable Layout/LineLength

    def test_should_sanitize_html_strings
      STRINGS.each do |input, expected|
        assert_equal expected, filter(input)
      end
    end

    # samples taken from the Sanitize test suite
    PROTOCOLS = {
      'protocol-based JS injection: simple, no spaces' => [
        '<a href="javascript:alert(\'XSS\');">foo</a>',
        '<a>foo</a>'
      ],

      'protocol-based JS injection: simple, spaces before' => [
        '<a href="javascript    :alert(\'XSS\');">foo</a>',
        '<a>foo</a>'
      ],

      'protocol-based JS injection: simple, spaces after' => [
        '<a href="javascript:    alert(\'XSS\');">foo</a>',
        '<a>foo</a>'
      ],

      'protocol-based JS injection: simple, spaces before and after' => [
        '<a href="javascript    :   alert(\'XSS\');">foo</a>',
        '<a>foo</a>'
      ],

      'protocol-based JS injection: preceding colon' => [
        '<a href=":javascript:alert(\'XSS\');">foo</a>',
        '<a>foo</a>'
      ],

      'protocol-based JS injection: UTF-8 encoding' => [
        '<a href="javascript&#58;">foo</a>',
        '<a>foo</a>'
      ],

      'protocol-based JS injection: long UTF-8 encoding' => [
        '<a href="javascript&#0058;">foo</a>',
        '<a>foo</a>'
      ],

      # rubocop:disable Layout/LineLength
      'protocol-based JS injection: long UTF-8 encoding without semicolons' => [
        '<a href=&#0000106&#0000097&#0000118&#0000097&#0000115&#0000099&#0000114&#0000105&#0000112&#0000116&#0000058&#0000097&#0000108&#0000101&#0000114&#0000116&#0000040&#0000039&#0000088&#0000083&#0000083&#0000039&#0000041>foo</a>',
        '<a>foo</a>'
      ],
      # rubocop:enable Layout/LineLength

      'protocol-based JS injection: hex encoding' => [
        '<a href="javascript&#x3A;">foo</a>',
        '<a>foo</a>'
      ],

      'protocol-based JS injection: long hex encoding' => [
        '<a href="javascript&#x003A;">foo</a>',
        '<a>foo</a>'
      ],

      'protocol-based JS injection: hex encoding without semicolons' => [
        '<a href=&#x6A&#x61&#x76&#x61&#x73&#x63&#x72&#x69&#x70&#x74&#x3A&#x61&#x6C&#x65&#x72&#x74&#x28&#x27&#x58&#x53&#x53&#x27&#x29>foo</a>',
        '<a>foo</a>'
      ],

      'protocol-based JS injection: null char' => [
        "<img src=java\0script:alert(\"XSS\")>",
        '<img src="java">'
        # '<img>'
      ],

      'protocol-based JS injection: invalid URL char' => [
        '<img src=java\script:alert("XSS")>',
        '<img>'
      ],

      'protocol-based JS injection: spaces and entities' => [
        '<img src=" &#14;  javascript:alert(\'XSS\');">',
        '<img src="">'
        # '<img>'
      ],

      'protocol whitespace' => [
        '<a href=" http://example.com/"></a>',
        '<a href="http://example.com/"></a>'
      ],

      'data images sources' => [
        '<img src="data:image/png;base64,foobar">',
        '<img>'
      ],

      'data URIs' => [
        '<a href="data:text/html;base64,foobar">XSS</a>',
        '<a>XSS</a>'
      ],

      'vbscript URIs' => [
        '<a href="vbscript:foobar">XSS</a>',
        '<a>XSS</a>'
      ],
    }

    PROTOCOLS.each do |name, strings|
      test "should not allow #{name}" do
        input, expected = *strings
        assert_equal expected, filter(input)
      end
    end
  end
end
