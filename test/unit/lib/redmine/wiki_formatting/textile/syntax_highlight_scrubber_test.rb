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

class Redmine::WikiFormatting::Textile::SyntaxHighlightScrubberTest < ActiveSupport::TestCase
  def filter(html)
    fragment = Redmine::WikiFormatting::HtmlParser.parse(html)
    scrubber = Redmine::WikiFormatting::Textile::SyntaxHighlightScrubber.new
    fragment.scrub!(scrubber)
    fragment.to_s
  end

  def test_should_highlight_supported_language
    input = <<~HTML
      <pre><code class="ruby">
      def foo
      end
      </code></pre>
    HTML
    assert_match(/class="ruby syntaxhl" data-language="ruby"/, filter(input))
  end

  def test_should_add_mermaid_controller_attribute_for_mermaid_language
    input = <<~HTML
      <pre><code class="mermaid">
      graph TD;
      A--&gt;B;
      </code></pre>
    HTML
    expected = <<~HTML
      <pre><code data-language="mermaid" data-controller="mermaid">graph TD;
      A--&gt;B;
      </code></pre>
    HTML
    assert_equal expected, filter(input)
  end

  def test_should_add_mermaid_controller_attribute_regardless_of_language_case
    input = <<~HTML
      <pre><code class="Mermaid">
      graph TD;
      </code></pre>
    HTML
    assert_match(/data-language="Mermaid" data-controller="mermaid"/, filter(input))
  end

  def test_should_not_add_mermaid_controller_attribute_for_inline_code
    input = '<p>Inline <code class="mermaid">graph TD; A--&gt;B;</code> in a sentence.</p>'
    result = filter(input)
    assert_no_match(/data-controller/, result)
    assert_match(/data-language="mermaid"/, result)
  end

  def test_should_not_add_mermaid_controller_attribute_for_other_languages
    input = <<~HTML
      <pre><code class="ruby">
      def foo
      end
      </code></pre>
    HTML
    assert_no_match(/data-controller/, filter(input))
  end
end
