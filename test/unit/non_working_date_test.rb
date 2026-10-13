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

require_relative '../test_helper'

class NonWorkingDateTest < ActiveSupport::TestCase
  def test_dates_should_be_cached_and_refreshed_on_change
    non_working_date = NonWorkingDate.create!(:date => '2026-08-13')
    assert_equal [Date.new(2026, 8, 13)], NonWorkingDate.sorted_dates
    assert_no_queries {NonWorkingDate.sorted_dates}

    non_working_date.update!(:date => '2026-08-14')
    assert_equal [Date.new(2026, 8, 14)], NonWorkingDate.sorted_dates

    non_working_date.destroy
    assert_empty NonWorkingDate.sorted_dates
  end
end
