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

class CalendarTest < ActiveSupport::TestCase
  def test_monthly
    c = Redmine::Helpers::Calendar.new(Date.today, :fr, :month)
    assert_equal [1, 7], [c.startdt.cwday, c.enddt.cwday]

    c = Redmine::Helpers::Calendar.new('2007-07-14'.to_date, :fr, :month)
    assert_equal ['2007-06-25'.to_date, '2007-08-05'.to_date], [c.startdt, c.enddt]

    c = Redmine::Helpers::Calendar.new(Date.today, :en, :month)
    assert_equal [7, 6], [c.startdt.cwday, c.enddt.cwday]
  end

  def test_weekly
    c = Redmine::Helpers::Calendar.new(Date.today, :fr, :week)
    assert_equal [1, 7], [c.startdt.cwday, c.enddt.cwday]

    c = Redmine::Helpers::Calendar.new('2007-07-14'.to_date, :fr, :week)
    assert_equal ['2007-07-09'.to_date, '2007-07-15'.to_date], [c.startdt, c.enddt]

    c = Redmine::Helpers::Calendar.new(Date.today, :en, :week)
    assert_equal [7, 6], [c.startdt.cwday, c.enddt.cwday]
  end

  def test_monthly_start_day
    [1, 6, 7].each do |day|
      with_settings :start_of_week => day do
        c = Redmine::Helpers::Calendar.new(Date.today, :en, :month)
        assert_equal day, c.startdt.cwday
        assert_equal (day + 5) % 7 + 1, c.enddt.cwday
      end
    end
  end

  def test_weekly_start_day
    [1, 6, 7].each do |day|
      with_settings :start_of_week => day do
        c = Redmine::Helpers::Calendar.new(Date.today, :en, :week)
        assert_equal day, c.startdt.cwday
        assert_equal (day + 5) % 7 + 1, c.enddt.cwday
      end
    end
  end

  def test_events_on_should_return_versions_only_on_their_due_date
    version = versions(:versions_002)
    assert_not_equal version.start_date, version.due_date

    c = Redmine::Helpers::Calendar.new(version.due_date, :en, :month)
    c.events = [version]
    assert_equal [version], c.events_on(version.due_date)
    assert_empty c.events_on(version.start_date)
  end
end
