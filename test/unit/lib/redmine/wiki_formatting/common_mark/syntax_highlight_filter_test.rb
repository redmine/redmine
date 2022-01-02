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
  require 'redmine/wiki_formatting/common_mark/syntax_highlight_filter'

  class Redmine::WikiFormatting::CommonMark::SyntaxHighlightFilterTest < ActiveSupport::TestCase
    def filter(html)
      Redmine::WikiFormatting::CommonMark::SyntaxHighlightFilter.to_html(html, @options)
    end

    def setup
      @options = { }
    end

    def test_should_highlight_supported_language
      input = <<~HTML
        <pre><code class="language-ruby">
        def foo
        end
        </code></pre>
      HTML
      expected = <<~HTML
        <pre><code class="ruby syntaxhl" data-language="ruby">
        <span class="k">def</span> <span class="nf">foo</span>
        <span class="k">end</span>
        </code></pre>
      HTML
      assert_equal expected, filter(input)
    end

    def test_should_highlight_supported_language_with_special_chars
      input = <<~HTML
        <pre><code class="language-c-k&amp;r">
        int i;
        </code></pre>
      HTML
      expected = <<~HTML
        <pre><code data-language="c-k&amp;r">
        int i;
        </code></pre>
      HTML
      assert_equal expected, filter(input)
    end

    def test_should_strip_code_class_and_preserve_data_language_attr_for_unknown_language
      input = <<~HTML
        <pre><code class="language-foobar">
        def foo
        end
        </code></pre>
      HTML
      expected = <<~HTML
        <pre><code data-language="foobar">
        def foo
        end
        </code></pre>
      HTML
      assert_equal expected, filter(input)
    end

    def test_should_ignore_code_without_class
      input = <<~HTML
        <pre><code>
        def foo
        end
        </code></pre>
      HTML
      assert_equal input, filter(input)
    end
  end
end
