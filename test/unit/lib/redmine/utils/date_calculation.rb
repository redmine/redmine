# Redmine - project management software
# Copyright (C) 2006-2016  Jean-Philippe Lang
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

class Redmine::Utils::DateCalculationTest < ActiveSupport::TestCase
  include Redmine::Utils::DateCalculation

  def test_working_days_without_non_working_week_days
    with_settings :non_working_week_days => [] do
      assert_working_days 18, '2012-10-09', '2012-10-27'
      assert_working_days  6, '2012-10-09', '2012-10-15'
      assert_working_days  5, '2012-10-09', '2012-10-14'
      assert_working_days  3, '2012-10-09', '2012-10-12'
      assert_working_days  3, '2012-10-14', '2012-10-17'
      assert_working_days 16, '2012-10-14', '2012-10-30'
    end
  end

  def test_working_days_with_non_working_week_days
    with_settings :non_working_week_days => %w(6 7) do
      assert_working_days 14, '2012-10-09', '2012-10-27'
      assert_working_days  4, '2012-10-09', '2012-10-15'
      assert_working_days  4, '2012-10-09', '2012-10-14'
      assert_working_days  3, '2012-10-09', '2012-10-12'
      assert_working_days  8, '2012-10-09', '2012-10-19'
      assert_working_days  8, '2012-10-11', '2012-10-23'
      assert_working_days  2, '2012-10-14', '2012-10-17'
      assert_working_days 11, '2012-10-14', '2012-10-30'
    end
  end

  def test_add_working_days_without_non_working_week_days
    with_settings :non_working_week_days => [] do
      assert_add_working_days '2012-10-10', '2012-10-10', 0
      assert_add_working_days '2012-10-11', '2012-10-10', 1
      assert_add_working_days '2012-10-12', '2012-10-10', 2
      assert_add_working_days '2012-10-13', '2012-10-10', 3
      assert_add_working_days '2012-10-25', '2012-10-10', 15
    end
  end

  def test_add_working_days_with_non_working_week_days
    with_settings :non_working_week_days => %w(6 7) do
      assert_add_working_days '2012-10-10', '2012-10-10', 0
      assert_add_working_days '2012-10-11', '2012-10-10', 1
      assert_add_working_days '2012-10-12', '2012-10-10', 2
      assert_add_working_days '2012-10-15', '2012-10-10', 3
      assert_add_working_days '2012-10-31', '2012-10-10', 15
      assert_add_working_days '2012-10-19', '2012-10-09', 8
      assert_add_working_days '2012-10-23', '2012-10-11', 8
    end
  end

  def assert_working_days(expected_days, from, to)
    assert_equal expected_days, working_days(from.to_date, to.to_date)
  end

  def assert_add_working_days(expected_date, from, working_days)
    assert_equal expected_date.to_date, add_working_days(from.to_date, working_days)
  end
end
