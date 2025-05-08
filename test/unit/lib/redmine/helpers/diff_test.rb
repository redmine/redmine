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

class DiffTest < ActiveSupport::TestCase
  def test_diff
    diff = Redmine::Helpers::Diff.new("foo", "bar")
    assert_not_nil diff
  end

  def test_dont_double_escape
    # 3 cases to test in the before: first word, last word, everything inbetween
    before = "<stuff> with html & special chars</danger>"
    # all words in after are treated equal
    after  = "other stuff <script>alert('foo');</alert>"

    computed_diff = Redmine::Helpers::Diff.new(before, after).to_html
    expected_diff =
      '<span class="diff_in">&lt;stuff&gt; with html &amp; special chars&lt;/danger&gt;</span>' \
        ' <span class="diff_out">other stuff &lt;script&gt;alert(&#39;foo&#39;);&lt;/alert&gt;</span>'
    assert_equal computed_diff, expected_diff
  end
end
