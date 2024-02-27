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

require_relative '../../../../test_helper'

class Redmine::WikiFormatting::HtmlSanitizerTest < ActiveSupport::TestCase
  def setup
    @sanitizer = Redmine::WikiFormatting::HtmlSanitizer
  end

  def test_should_allow_links_with_safe_url_schemes_and_append_external_class
    %w(http https ftp ssh foo).each do |scheme|
      input = %(<a href="#{scheme}://example.org/">foo</a>)
      assert_equal %(<a href="#{scheme}://example.org/" class="external">foo</a>), @sanitizer.call(input)
    end
  end

  def test_should_reject_links_with_unsafe_url_schemes
    input = %(<a href="javascript:alert('hello');">foo</a>)
    assert_equal "<a>foo</a>", @sanitizer.call(input)
  end
end
