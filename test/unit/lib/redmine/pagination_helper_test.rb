# Redmine - project management software
# Copyright (C) 2006-2015  Jean-Philippe Lang
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

require File.expand_path('../../../../test_helper', __FILE__)

class PaginationHelperTest < ActionView::TestCase
  include Redmine::Pagination::Helper

  def test_per_page_options_should_return_usefull_values
    with_settings :per_page_options => '10, 25, 50, 100' do
      assert_equal [], per_page_options(10, 3)
      assert_equal [], per_page_options(25, 3)
      assert_equal [10, 25], per_page_options(10, 22)
      assert_equal [10, 25], per_page_options(25, 22)
      assert_equal [10, 25, 50], per_page_options(50, 22)
      assert_equal [10, 25, 50], per_page_options(25, 26)
      assert_equal [10, 25, 50, 100], per_page_options(25, 120)
    end
  end
end
