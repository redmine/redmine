# frozen_string_literal: true

#
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
require 'digest/md5'

class Redmine::WikiFormatting::TextileFormatterTest < ActionView::TestCase

  def setup
    @formatter = Redmine::WikiFormatting::Textile::Formatter
  end

  MODIFIERS = {
    "*" => 'strong', # bold
    "_" => 'em',     # italic
    "+" => 'ins',    # underline
    "-" => 'del',    # deleted
    "^" => 'sup',    # superscript
    "~" => 'sub'     # subscript
  }

  def test_modifiers
    assert_html_output(
      '*bold*'                => '<strong>bold</strong>',
      'before *bold*'         => 'before <strong>bold</strong>',
      '*bold* after'          => '<strong>bold</strong> after',
      '*two words*'           => '<strong>two words</strong>',
      '*two*words*'           => '<strong>two*words</strong>',
      '*two * words*'         => '<strong>two * words</strong>',
      '*two* *words*'         => '<strong>two</strong> <strong>words</strong>',
      '*(two)* *(words)*'     => '<strong>(two)</strong> <strong>(words)</strong>'
    )
  end

  def test_modifiers_combination
    MODIFIERS.each do |m1, tag1|
      MODIFIERS.each do |m2, tag2|
        next if m1 == m2
        text = "#{m2}#{m1}Phrase modifiers#{m1}#{m2}"
        html = "<#{tag2}><#{tag1}>Phrase modifiers</#{tag1}></#{tag2}>"
        assert_html_output text => html
      end
    end
  end

  def test_modifier_should_work_with_one_non_ascii_character
    assert_html_output "*Ä*" => "<strong>Ä</strong>"
  end

  def test_styles
    # single style
    assert_html_output({
      'p{color:red}. text'           => '<p style="color:red;">text</p>',
      'p{color:red;}. text'          => '<p style="color:red;">text</p>',
      'p{color: red}. text'          => '<p style="color: red;">text</p>',
      'p{color:#f00}. text'          => '<p style="color:#f00;">text</p>',
      'p{color:#ff0000}. text'       => '<p style="color:#ff0000;">text</p>',
      'p{border:10px}. text'         => '<p style="border:10px;">text</p>',
      'p{border:10}. text'           => '<p style="border:10;">text</p>',
      'p{border:10%}. text'          => '<p style="border:10%;">text</p>',
      'p{border:10em}. text'         => '<p style="border:10em;">text</p>',
      'p{border:1.5em}. text'        => '<p style="border:1.5em;">text</p>',
      'p{border-left:1px}. text'     => '<p style="border-left:1px;">text</p>',
      'p{border-right:1px}. text'    => '<p style="border-right:1px;">text</p>',
      'p{border-top:1px}. text'      => '<p style="border-top:1px;">text</p>',
      'p{border-bottom:1px}. text'   => '<p style="border-bottom:1px;">text</p>',
      'p{width:50px}. text'          => '<p style="width:50px;">text</p>',
      'p{max-width:100px}. text'     => '<p style="max-width:100px;">text</p>',
      'p{height:40px}. text'         => '<p style="height:40px;">text</p>',
      'p{max-height:80px}. text'     => '<p style="max-height:80px;">text</p>',
      }, false)

    # multiple styles
    assert_html_output({
      'p{color:red; border-top:1px}. text'   => '<p style="color:red;border-top:1px;">text</p>',
      'p{color:red ; border-top:1px}. text'  => '<p style="color:red;border-top:1px;">text</p>',
      'p{color:red;border-top:1px}. text'    => '<p style="color:red;border-top:1px;">text</p>',
      }, false)

    # styles with multiple values
    assert_html_output({
      'p{border:1px solid red;}. text'             => '<p style="border:1px solid red;">text</p>',
      'p{border-top-left-radius: 10px 5px;}. text' => '<p style="border-top-left-radius: 10px 5px;">text</p>',
      }, false)
  end

  def test_invalid_styles_should_be_filtered
    assert_html_output({
      'p{invalid}. text'                     => '<p>text</p>',
      'p{invalid:red}. text'                 => '<p>text</p>',
      'p{color:(red)}. text'                 => '<p>text</p>',
      'p{color:red;invalid:blue}. text'      => '<p style="color:red;">text</p>',
      'p{invalid:blue;color:red}. text'      => '<p style="color:red;">text</p>',
      'p{color:"}. text'                     => '<p>p{color:"}. text</p>',
      }, false)
  end

  def test_inline_code
    assert_html_output(
      'this is @some code@'      => 'this is <code>some code</code>',
      '@<Location /redmine>@'    => '<code>&lt;Location /redmine&gt;</code>'
    )
  end

  def test_lang_attribute
    assert_html_output(
      '*[fr]French*'      => '<strong lang="fr">French</strong>',
      '*[fr-fr]French*'   => '<strong lang="fr-fr">French</strong>',
      '*[fr_fr]French*'   => '<strong lang="fr_fr">French</strong>'
    )
  end

  def test_lang_attribute_should_ignore_invalid_value
    assert_html_output(
      '*[fr3]French*'      => '<strong>[fr3]French</strong>'
    )
  end

  def test_nested_lists
    raw = <<-RAW
# Item 1
# Item 2
** Item 2a
** Item 2b
# Item 3
** Item 3a
RAW

    expected = <<-EXPECTED
<ol>
  <li>Item 1</li>
  <li>Item 2
    <ul>
      <li>Item 2a</li>
      <li>Item 2b</li>
    </ul>
  </li>
  <li>Item 3
    <ul>
      <li>Item 3a</li>
    </ul>
  </li>
</ol>
EXPECTED

    assert_equal expected.gsub(%r{\s+}, ''), to_html(raw).gsub(%r{\s+}, '')

    raw = <<~RAW
      * Item-1

        * Item-1a
        * Item-1b
    RAW
    expected = <<~EXPECTED
      <ul>
        <li>Item-1
          <ul>
            <li>Item-1a</li>
            <li>Item-1b</li>
          </ul>
        </li>
      </ul>
    EXPECTED
    assert_equal expected.gsub(%r{\s+}, ''), to_html(raw).gsub(%r{\s+}, '')
  end

  def test_escaping
    assert_html_output(
      'this is a <script>'      => 'this is a &lt;script&gt;'
    )
  end

  def test_kbd
    assert_html_output({
      '<kbd>test</kbd>'         => '<kbd>test</kbd>'
    }, false)
  end

  def test_use_of_backslashes_followed_by_numbers_in_headers
    assert_html_output({
      'h1. 2009\02\09'      => '<h1>2009\02\09</h1>'
    }, false)
  end

  def test_double_dashes_should_not_strikethrough
    assert_html_output(
      'double -- dashes -- test'  => 'double -- dashes -- test',
      'double -- *dashes* -- test'  => 'double -- <strong>dashes</strong> -- test'
    )
  end

  def test_abbreviations
    assert_html_output(
      'this is an abbreviation: GPL(General Public License)' => 'this is an abbreviation: <abbr title="General Public License">GPL</abbr>',
      '2 letters JP(Jean-Philippe) abbreviation' => '2 letters <abbr title="Jean-Philippe">JP</abbr> abbreviation',
      'GPL(This is a double-quoted "title")' => '<abbr title="This is a double-quoted &quot;title&quot;">GPL</abbr>'
    )
  end

  def test_blockquote
    # orig raw text
    raw = <<-RAW
John said:
> Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Maecenas sed libero.
> Nullam commodo metus accumsan nulla. Curabitur lobortis dui id dolor.
> * Donec odio lorem,
> * sagittis ac,
> * malesuada in,
> * adipiscing eu, dolor.
>
> >Nulla varius pulvinar diam. Proin id arcu id lorem scelerisque condimentum. Proin vehicula turpis vitae lacus.
> Proin a tellus. Nam vel neque.

He's right.
RAW

    # expected html
    expected = <<-EXPECTED
<p>John said:</p>
<blockquote>
Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Maecenas sed libero.<br />
Nullam commodo metus accumsan nulla. Curabitur lobortis dui id dolor.
<ul>
  <li>Donec odio lorem,</li>
  <li>sagittis ac,</li>
  <li>malesuada in,</li>
  <li>adipiscing eu, dolor.</li>
</ul>
<blockquote>
<p>Nulla varius pulvinar diam. Proin id arcu id lorem scelerisque condimentum. Proin vehicula turpis vitae lacus.</p>
</blockquote>
<p>Proin a tellus. Nam vel neque.</p>
</blockquote>
<p>He's right.</p>
EXPECTED

    assert_equal expected.gsub(%r{\s+}, ''), to_html(raw).gsub(%r{\s+}, '')
  end

  def test_table
    raw = <<-RAW
This is a table with empty cells:

|cell11|cell12||
|cell21||cell23|
|cell31|cell32|cell33|
RAW

    expected = <<-EXPECTED
<p>This is a table with empty cells:</p>

<table>
  <tr><td>cell11</td><td>cell12</td><td></td></tr>
  <tr><td>cell21</td><td></td><td>cell23</td></tr>
  <tr><td>cell31</td><td>cell32</td><td>cell33</td></tr>
</table>
EXPECTED

    assert_equal expected.gsub(%r{\s+}, ''), to_html(raw).gsub(%r{\s+}, '')
  end

  def test_table_with_alignment
    raw = <<-RAW
|>. right|
|<. left|
|<>. justify|
RAW

    expected = <<-EXPECTED
<table>
  <tr><td style="text-align:right;">right</td></tr>
  <tr><td style="text-align:left;">left</td></tr>
  <tr><td style="text-align:justify;">justify</td></tr>
</table>
EXPECTED

    assert_equal expected.gsub(%r{\s+}, ''), to_html(raw).gsub(%r{\s+}, '')
  end

  def test_table_with_trailing_whitespace
    raw = <<-RAW
This is a table with trailing whitespace in one row:

|cell11|cell12|
|cell21|cell22|
|cell31|cell32|
RAW

    expected = <<-EXPECTED
<p>This is a table with trailing whitespace in one row:</p>

<table>
  <tr><td>cell11</td><td>cell12</td></tr>
  <tr><td>cell21</td><td>cell22</td></tr>
  <tr><td>cell31</td><td>cell32</td></tr>
</table>
EXPECTED

    assert_equal expected.gsub(%r{\s+}, ''), to_html(raw).gsub(%r{\s+}, '')
  end

  def test_table_with_line_breaks
    raw = <<-RAW
This is a table with line breaks:

|cell11
continued|cell12||
|-cell21-||cell23
cell23 line2
cell23 *line3*|
|cell31|cell32
cell32 line2|cell33|

RAW

    expected = <<-EXPECTED
<p>This is a table with line breaks:</p>

<table>
  <tr>
    <td>cell11<br />continued</td>
    <td>cell12</td>
    <td></td>
  </tr>
  <tr>
    <td><del>cell21</del></td>
    <td></td>
    <td>cell23<br/>cell23 line2<br/>cell23 <strong>line3</strong></td>
  </tr>
  <tr>
    <td>cell31</td>
    <td>cell32<br/>cell32 line2</td>
    <td>cell33</td>
  </tr>
</table>
EXPECTED

    assert_equal expected.gsub(%r{\s+}, ''), to_html(raw).gsub(%r{\s+}, '')
  end

  def test_tables_with_lists
    raw = <<-RAW
This is a table with lists:

|cell11|cell12|
|cell21|ordered list
# item
# item 2|
|cell31|unordered list
* item
* item 2|

RAW

    expected = <<-EXPECTED
<p>This is a table with lists:</p>

<table>
  <tr>
    <td>cell11</td>
    <td>cell12</td>
  </tr>
  <tr>
    <td>cell21</td>
    <td>ordered list<br /># item<br /># item 2</td>
  </tr>
  <tr>
    <td>cell31</td>
    <td>unordered list<br />* item<br />* item 2</td>
  </tr>
</table>
EXPECTED

    assert_equal expected.gsub(%r{\s+}, ''), to_html(raw).gsub(%r{\s+}, '')
  end

  def test_textile_should_not_mangle_brackets
    assert_equal '<p>[msg1][msg2]</p>', to_html('[msg1][msg2]')
  end

  def test_textile_should_escape_image_urls
    # this is onclick="alert('XSS');" in encoded form
    raw = '!/images/comment.png"onclick=&#x61;&#x6c;&#x65;&#x72;&#x74;&#x28;&#x27;&#x58;&#x53;&#x53;&#x27;&#x29;;&#x22;!'
    expected = '<p><img src="/images/comment.png&quot;onclick=&amp;#x61;&amp;#x6c;&amp;#x65;&amp;#x72;&amp;#x74;&amp;#x28;&amp;#x27;&amp;#x58;&amp;#x53;&amp;#x53;&amp;#x27;&amp;#x29;;&amp;#x22;" alt="" /></p>'
    assert_equal expected.gsub(%r{\s+}, ''), to_html(raw).gsub(%r{\s+}, '')
  end

  STR_WITHOUT_PRE = [
    # 0
    <<~STR.chomp,
      h1. Title

      Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Maecenas sed libero.
    STR
    # 1
    <<~STR.chomp,
      h2. Heading 2

      Maecenas sed elit sit amet mi accumsan vestibulum non nec velit. Proin porta tincidunt lorem, consequat rhoncus dolor fermentum in.

      Cras ipsum felis, ultrices at porttitor vel, faucibus eu nunc.
    STR
    # 2
    <<~STR.chomp,
      h2. Heading 2

      Morbi facilisis accumsan orci non pharetra.

      h3. Heading 3

      Nulla nunc nisi, egestas in ornare vel, posuere ac libero.
    STR
    # 3
    <<~STR.chomp,
      h3. Heading 3

      Praesent eget turpis nibh, a lacinia nulla.
    STR
    # 4
    <<~STR.chomp,
      h2. Heading 2

      Ut rhoncus elementum adipiscing.
    STR
  ]
  TEXT_WITHOUT_PRE = STR_WITHOUT_PRE.join("\n\n").freeze

  def test_get_section_should_return_the_requested_section_and_its_hash
    assert_section_with_hash STR_WITHOUT_PRE[1], TEXT_WITHOUT_PRE, 2
    assert_section_with_hash STR_WITHOUT_PRE[2..3].join("\n\n"), TEXT_WITHOUT_PRE, 3
    assert_section_with_hash STR_WITHOUT_PRE[3], TEXT_WITHOUT_PRE, 5
    assert_section_with_hash STR_WITHOUT_PRE[4], TEXT_WITHOUT_PRE, 6

    assert_section_with_hash '', TEXT_WITHOUT_PRE, 0
    assert_section_with_hash '', TEXT_WITHOUT_PRE, 10
  end

  def test_update_section_should_update_the_requested_section
    replacement = "New text"

    assert_equal [STR_WITHOUT_PRE[0], replacement, STR_WITHOUT_PRE[2..4]].flatten.join("\n\n"), @formatter.new(TEXT_WITHOUT_PRE).update_section(2, replacement)
    assert_equal [STR_WITHOUT_PRE[0..1], replacement, STR_WITHOUT_PRE[4]].flatten.join("\n\n"), @formatter.new(TEXT_WITHOUT_PRE).update_section(3, replacement)
    assert_equal [STR_WITHOUT_PRE[0..2], replacement, STR_WITHOUT_PRE[4]].flatten.join("\n\n"), @formatter.new(TEXT_WITHOUT_PRE).update_section(5, replacement)
    assert_equal [STR_WITHOUT_PRE[0..3], replacement].flatten.join("\n\n"), @formatter.new(TEXT_WITHOUT_PRE).update_section(6, replacement)

    assert_equal TEXT_WITHOUT_PRE, @formatter.new(TEXT_WITHOUT_PRE).update_section(0, replacement)
    assert_equal TEXT_WITHOUT_PRE, @formatter.new(TEXT_WITHOUT_PRE).update_section(10, replacement)
  end

  def test_update_section_with_hash_should_update_the_requested_section
    replacement = "New text"

    assert_equal [STR_WITHOUT_PRE[0], replacement, STR_WITHOUT_PRE[2..4]].flatten.join("\n\n"),
      @formatter.new(TEXT_WITHOUT_PRE).update_section(2, replacement, Digest::MD5.hexdigest(STR_WITHOUT_PRE[1]))
  end

  def test_update_section_with_wrong_hash_should_raise_an_error
    assert_raise Redmine::WikiFormatting::StaleSectionError do
      @formatter.new(TEXT_WITHOUT_PRE).update_section(2, "New text", Digest::MD5.hexdigest("Old text"))
    end
  end

  STR_WITH_PRE = [
    # 0
    <<~STR.chomp,
      h1. Title

      Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Maecenas sed libero.
    STR
    # 1
    <<~STR.chomp,
      h2. Heading 2

      <pre><code class=\"ruby\">
        def foo
        end
      </code></pre>

      <pre><code><pre><code class=\"ruby\">
        Place your code here.
      </code></pre>
      </code></pre>

      Morbi facilisis accumsan orci non pharetra.

      <pre>
      Pre Content:

      h2. Inside pre

      <tag> inside pre block

      Morbi facilisis accumsan orci non pharetra.
      </pre>
    STR
    # 2
    <<~STR.chomp,
      h3. Heading 3

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

    assert_equal [STR_WITH_PRE[0..1], "New text"].flatten.join("\n\n"),
      @formatter.new(text).update_section(3, replacement)
  end

  def test_get_section_should_support_lines_with_spaces_before_heading
    # the lines after Content 2 and Heading 4 contain a space
    text = <<-STR
h1. Heading 1

Content 1

h1. Heading 2

Content 2

h1. Heading 3

Content 3

h1. Heading 4

Content 4
STR

    [1, 2, 3, 4].each do |index|
      assert_match /\Ah1. Heading #{index}.+Content #{index}/m, @formatter.new(text).get_section(index).first
    end
  end

  def test_get_section_should_support_headings_starting_with_a_tab
    text = <<-STR
h1.\tHeading 1

Content 1

h1. Heading 2

Content 2
STR

    assert_match /\Ah1.\tHeading 1\s+Content 1\z/, @formatter.new(text).get_section(1).first
  end

  def test_should_not_allow_arbitrary_class_attribute_on_offtags
    %w(code pre kbd).each do |tag|
      assert_html_output({"<#{tag} class=\"foo\">test</#{tag}>" => "<#{tag}>test</#{tag}>"}, false)
      assert_html_output({"<#{tag} class='foo'>test</#{tag}>" => "<#{tag}>test</#{tag}>"}, false)
      assert_html_output({"<#{tag} class=\"ruby foo\">test</#{tag}>" => "<#{tag}>test</#{tag}>"}, false)
      assert_html_output({"<#{tag} class='ruby foo'>test</#{tag}>" => "<#{tag}>test</#{tag}>"}, false)
      assert_html_output({"<#{tag} class=\"ruby \"foo\" bar\">test</#{tag}>" => "<#{tag}>test</#{tag}>"}, false)
    end

    assert_html_output({"<notextile class=\"foo\">test</notextile>" => "test"}, false)
    assert_html_output({"<notextile class='foo'>test</notextile>" => "test"}, false)
    assert_html_output({"<notextile class=\"ruby foo\">test</notextile>" => "test"}, false)
    assert_html_output({"<notextile class='ruby foo'>test</notextile>" => "test"}, false)
    assert_html_output({"<notextile class=\"ruby \"foo\" bar\">test</notextile>" => "test"}, false)
  end

  def test_should_allow_valid_language_class_attribute_on_code_tags
    # language name is double-quoted
    assert_html_output({"<code class=\"ruby\">test</code>" => "<code class=\"ruby syntaxhl\"><span class=\"nb\">test</span></code>"}, false)
    # language name is single-quoted
    assert_html_output({"<code class='ruby'>test</code>" => "<code class=\"ruby syntaxhl\"><span class=\"nb\">test</span></code>"}, false)
  end

  def test_should_not_allow_valid_language_class_attribute_on_non_code_offtags
    %w(pre kbd).each do |tag|
      assert_html_output({"<#{tag} class=\"ruby\">test</#{tag}>" => "<#{tag}>test</#{tag}>"}, false)
    end

    assert_html_output({"<notextile class=\"ruby\">test</notextile>" => "test"}, false)
  end

  def test_should_prefix_class_attribute_on_tags
    assert_html_output({
      '!(foo)test.png!' => "<p><img src=\"test.png\" class=\"wiki-class-foo\" alt=\"\" /></p>",
      '%(foo)test%'     => "<p><span class=\"wiki-class-foo\">test</span></p>",
      'p(foo). test'    => "<p class=\"wiki-class-foo\">test</p>",
      '|(foo). test|'   => "<table>\n\t\t<tr>\n\t\t\t<td class=\"wiki-class-foo\">test</td>\n\t\t</tr>\n\t</table>",
    }, false)
  end

  def test_should_prefix_id_attribute_on_tags
    assert_html_output({
      '!(#foo)test.png!' => "<p><img src=\"test.png\" id=\"wiki-id-foo\" alt=\"\" /></p>",
      '%(#foo)test%'     => "<p><span id=\"wiki-id-foo\">test</span></p>",
      'p(#foo). test'    => "<p id=\"wiki-id-foo\">test</p>",
      '|(#foo). test|'   => "<table>\n\t\t<tr>\n\t\t\t<td id=\"wiki-id-foo\">test</td>\n\t\t</tr>\n\t</table>",
    }, false)
  end

  def test_should_not_prefix_class_and_id_attributes_already_prefixed
    assert_html_output({
      '!(wiki-class-foo#wiki-id-bar)test.png!' => "<p><img src=\"test.png\" class=\"wiki-class-foo\" id=\"wiki-id-bar\" alt=\"\" /></p>",
    }, false)
  end

  def test_footnotes
    text = <<-STR
This is some text[1].

fn1. This is the foot note
STR

    expected = <<-EXPECTED
<p>This is some text<sup><a href=\"#fn1\">1</a></sup>.</p>
<p id="fn1" class="footnote"><sup>1</sup> This is the foot note</p>
EXPECTED

    assert_equal expected.gsub(%r{[\r\n\t]}, ''), to_html(text).gsub(%r{[\r\n\t]}, '')
  end

  # TODO: Remove this test after migrating to RedCloth 4
  def test_should_not_crash_with_special_input
    assert_nothing_raised { to_html(" \f") }
    assert_nothing_raised { to_html(" \v") }
  end

  def test_should_not_handle_as_preformatted_text_tags_that_starts_with_pre
    text = <<-STR
<pree>
  This is some text
</pree>
STR

    expected = <<-EXPECTED
<p>&lt;pree&gt;<br />
  This is some text<br />
&lt;/pree&gt;</p>
EXPECTED

    assert_equal expected.gsub(%r{[\r\n\t]}, ''), to_html(text).gsub(%r{[\r\n\t]}, '')
  end

  private

  def assert_html_output(to_test, expect_paragraph = true)
    to_test.each do |text, expected|
      assert_equal(( expect_paragraph ? "<p>#{expected}</p>" : expected ), @formatter.new(text).to_html, "Formatting the following text failed:\n===\n#{text}\n===\n")
    end
  end

  def to_html(text)
    @formatter.new(text).to_html
  end

  def assert_section_with_hash(expected, text, index)
    result = @formatter.new(text).get_section(index)

    assert_kind_of Array, result
    assert_equal 2, result.size
    assert_equal expected, result.first, "section content did not match"
    assert_equal Digest::MD5.hexdigest(expected), result.last, "section hash did not match"
  end
end
