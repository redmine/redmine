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

if Object.const_defined?(:CommonMarker)
  require 'redmine/wiki_formatting/common_mark/markdown_filter'

  class Redmine::WikiFormatting::CommonMark::MarkdownFilterTest < ActiveSupport::TestCase
    def filter(markdown)
      Redmine::WikiFormatting::CommonMark::MarkdownFilter.to_html(markdown)
    end

    # just a basic sanity test. more formatting tests in the formatter_test
    def test_should_render_markdown
      assert_equal "<p><strong>bold</strong></p>", filter("**bold**")
    end
  end
end
