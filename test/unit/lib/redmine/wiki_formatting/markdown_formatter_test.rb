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

require File.expand_path('../../../../../test_helper', __FILE__)

class Redmine::WikiFormatting::MarkdownFormatterTest < ActionView::TestCase
  def setup
    unless Object.const_defined?(:Redcarpet)
      skip "Redcarpet is not installed"
    end
    @formatter = Redmine::WikiFormatting::Markdown::Formatter
  end

  def test_syntax_error_in_image_reference_should_not_raise_exception
    assert @formatter.new("!>[](foo.png)").to_html
  end

  def test_empty_image_should_not_raise_exception
    assert @formatter.new("![]()").to_html
  end

  # re-using the formatter after getting above error crashes the
  # ruby interpreter. This seems to be related to
  # https://github.com/vmg/redcarpet/issues/318
  def test_should_not_crash_redcarpet_after_syntax_error
    @formatter.new("!>[](foo.png)").to_html rescue nil
    assert @formatter.new("![](foo.png)").to_html.present?
  end

  def test_inline_style
    assert_equal "<p><strong>foo</strong></p>", @formatter.new("**foo**").to_html.strip
  end

  def test_not_set_intra_emphasis
    assert_equal "<p>foo_bar_baz</p>", @formatter.new("foo_bar_baz").to_html.strip
  end

  def test_wiki_links_should_be_preserved
    text = 'This is a wiki link: [[Foo]]'
    assert_include '[[Foo]]', @formatter.new(text).to_html
  end

  def test_redmine_links_with_double_quotes_should_be_preserved
    text = 'This is a redmine link: version:"1.0"'
    assert_include 'version:"1.0"', @formatter.new(text).to_html
  end

  def test_should_support_syntax_highlight
    text = <<~STR
      ~~~ruby
      def foo
      end
      ~~~
    STR
    assert_select_in @formatter.new(text).to_html, 'pre code.ruby.syntaxhl' do
      assert_select 'span.k', :text => 'def'
      assert_select "[data-language='ruby']"
    end
  end

  def test_should_not_allow_invalid_language_for_code_blocks
    text = <<~STR
      ~~~foo
      test
      ~~~
    STR
    assert_equal "<pre><code data-language=\"foo\">test\n</code></pre>", @formatter.new(text).to_html
  end

  def test_should_preserve_code_block_language_in_data_language
    text = <<~STR
      ~~~c-k&r
      test
      ~~~
    STR
    assert_equal "<pre><code data-language=\"c-k&amp;r\">test\n</code></pre>", @formatter.new(text).to_html
  end

  def test_external_links_should_have_external_css_class
    text = 'This is a [link](http://example.net/)'
    assert_equal '<p>This is a <a href="http://example.net/" class="external">link</a></p>', @formatter.new(text).to_html.strip
  end

  def test_locals_links_should_not_have_external_css_class
    text = 'This is a [link](/issues)'
    assert_equal '<p>This is a <a href="/issues">link</a></p>', @formatter.new(text).to_html.strip
  end

  def test_markdown_should_not_require_surrounded_empty_line
    text = <<~STR
      This is a list:
      * One
      * Two
    STR
    assert_equal "<p>This is a list:</p>\n\n<ul>\n<li>One</li>\n<li>Two</li>\n</ul>", @formatter.new(text).to_html.strip
  end

  def test_footnotes
    text = <<~STR
      This is some text[^1].

      [^1]: This is the foot note
    STR
    expected = <<~EXPECTED
      <p>This is some text<sup id="fnref1"><a href="#fn1">1</a></sup>.</p>
      <div class="footnotes">
      <hr>
      <ol>

      <li id="fn1">
      <p>This is the foot note&nbsp;<a href="#fnref1">&#8617;</a></p>
      </li>

      </ol>
      </div>
    EXPECTED
    assert_equal expected.gsub(%r{[\r\n\t]}, ''), @formatter.new(text).to_html.gsub(%r{[\r\n\t]}, '')
  end

  STR_WITH_PRE = [
    # 0
    <<~STR.chomp,
      # Title

      Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Maecenas sed libero.
    STR
    # 1
    <<~STR.chomp,
      ## Heading 2

      ~~~ruby
        def foo
        end
      ~~~

      Morbi facilisis accumsan orci non pharetra.

      ~~~ ruby
      def foo
      end
      ~~~

      ```
      Pre Content:

      ## Inside pre

      <tag> inside pre block

      Morbi facilisis accumsan orci non pharetra.
      ```
    STR
    # 2
    <<~STR.chomp,
      ### Heading 3

      Nulla nunc nisi, egestas in ornare vel, posuere ac libero.
    STR
  ]

  def test_get_section_should_ignore_pre_content
    text = STR_WITH_PRE.join("\n\n")

    assert_section_with_hash STR_WITH_PRE[1..2].join("\n\n"), text, 2
    assert_section_with_hash STR_WITH_PRE[2], text, 3
  end

  def test_update_section_should_not_escape_pre_content_outside_section
    text = STR_WITH_PRE.join("\n\n")
    replacement = "New text"
    assert_equal(
      [STR_WITH_PRE[0..1], "New text"].flatten.join("\n\n"),
      @formatter.new(text).update_section(3, replacement)
    )
  end

  STR_SETEXT_LIKE = [
    # 0
    <<~STR.chomp,
      # Title
    STR
    # 1
    <<~STR.chomp,
      ## Heading 2

      Thematic breaks - not be confused with setext headings.

      ---

      Preceding CRLF is the default for web-submitted data.
      \r
      ---\r
      \r

      A space-only line does not mean much.
      \s
      ---

      End of thematic breaks.
    STR
    # 2
    <<~STR.chomp,
      ## Heading 2
      Nulla nunc nisi, egestas in ornare vel, posuere ac libero.
    STR
  ]

  STR_RARE_SETEXT_LIKE = [
    # 0
    <<~STR.chomp,
      # Title
    STR
    # 1
    <<~STR.chomp,
      ## Heading 2

      - item
      one
      -
      not a heading
    STR
    # 2
    <<~STR.chomp,
      ## Heading 2
      Nulla nunc nisi, egestas in ornare vel, posuere ac libero.
    STR
  ]

  def test_get_section_should_ignore_setext_like_text
    text = STR_SETEXT_LIKE.join("\n\n")
    assert_section_with_hash STR_SETEXT_LIKE[1], text, 2
    assert_section_with_hash STR_SETEXT_LIKE[2], text, 3
  end

  def test_get_section_should_ignore_rare_setext_like_text
    begin
      text = STR_RARE_SETEXT_LIKE.join("\n\n")
      assert_section_with_hash STR_RARE_SETEXT_LIKE[1], text, 2
      assert_section_with_hash STR_RARE_SETEXT_LIKE[2], text, 3
    rescue Minitest::Assertion => e
      skip "Section extraction is currently limited, see #35037. Known error: #{e.message}"
    end
    assert_not "This test should be adjusted when fixing the known error."
  end

  def test_should_support_underlined_text
    text = 'This _text_ should be underlined'
    assert_equal '<p>This <u>text</u> should be underlined</p>', format(text)
  end

  def test_should_autolink_mails
    input = "foo@example.org"
    assert_equal %(<p><a href="mailto:foo@example.org">foo@example.org</a></p>), format(input)

    # The redcloth autolinker parses "plain" mailto links a bit unfortunately.
    # We do the best we can here...
    input = "mailto:foo@example.org"
    assert_equal %(<p>mailto:<a href="mailto:foo@example.org">foo@example.org</a></p>), format(input)
  end

  def test_should_fixup_mailto_links
    input = "<mailto:foo@example.org>"
    assert_equal %(<p><a href="mailto:foo@example.org">foo@example.org</a></p>), format(input)
  end

  def test_should_fixup_autolinked_user_references
    text = "user:user@example.org"
    assert_equal "<p>#{text}</p>", format(text)

    text = "@user@example.org"
    assert_equal "<p>#{text}</p>", format(text)
  end

  def test_should_fixup_autolinked_hires_files
    text = "printscreen@2x.png"
    assert_equal "<p>#{text}</p>", format(text).strip
  end

  def test_should_allow_links_with_safe_url_schemes
    safe_schemes = %w(http https ftp)
    link_safe_schemes = %w(ssh foo)

    (safe_schemes + link_safe_schemes).each do |scheme|
      input = "[#{scheme}](#{scheme}://example.com)"
      expected = %(<p><a href="#{scheme}://example.com" class="external">#{scheme}</a></p>)

      assert_equal expected, format(input)
    end
  end

  def test_should_not_allow_links_with_unsafe_url_schemes
    unsafe_schemes = %w(data javascript vbscript)

    unsafe_schemes.each do |scheme|
      input = "[#{scheme}](#{scheme}:something)"
      assert_equal "<p>#{input}</p>", format(input)
    end
  end

  def test_should_allow_autolinks_with_safe_url_schemes
    safe_schemes = %w(http https ftp)
    link_safe_schemes = %w(ssh foo)

    (safe_schemes + link_safe_schemes).each do |scheme|
      input = "#{scheme}://example.org"
      expected = %(<p><a href="#{input}" class="external">#{input}</a></p>)

      assert_equal expected, format(input) if safe_schemes.include?(scheme)
      assert_equal expected, format("<#{input}>")
    end
  end

  def test_should_not_autolink_unsafe_schemes
    unsafe_schemes = %w(data javascript vbscript)

    unsafe_schemes.each do |scheme|
      link = "#{scheme}:something"

      assert_equal "<p>#{link}</p>", format(link)
      assert_equal "<p>#{link}</p>", format("<#{link}>")
    end
  end

  private

  def format(text)
    @formatter.new(text).to_html.strip
  end

  def assert_section_with_hash(expected, text, index)
    result = @formatter.new(text).get_section(index)

    assert_kind_of Array, result
    assert_equal 2, result.size
    assert_equal expected, result.first, "section content did not match"
    assert_equal Digest::MD5.hexdigest(expected), result.last, "section hash did not match"
  end
end
