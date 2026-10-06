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

class GanttHelperTest < Redmine::HelperTest
  include GanttHelper

  test 'chart layout scales days and selects header rows for each zoom level' do
    # Input zoom level, then expected pixels per day, header rows, and header visibility.
    [
      [1, 2, 1, false, false, false],
      [2, 4, 2, true, false, false],
      [3, 8, 3, true, true, false],
      [4, 16, 4, true, true, true]
    ].each do |level, pixels, rows, weeks, days, day_numbers|
      layout = chart_layout(zoom: level)

      assert_equal pixels, layout.zoom
      assert_equal rows * layout.header_height, layout.headers_height
      assert_equal weeks, layout.show_weeks?
      assert_equal days, layout.show_days?
      assert_equal day_numbers, layout.show_day_numbers?
    end
  end

  test 'chart width includes both endpoints of the date range' do
    layout = chart_layout(date_from: Date.new(2024, 2, 1), zoom: 3)

    # Leap February has 29 days; zoom level 3 represents each day with 8 pixels.
    assert_equal 232, layout.chart_width
  end

  test 'content and pane heights account for the rendered rows' do
    empty = chart_layout(number_of_rows: 0)
    populated = chart_layout(number_of_rows: 10)

    assert_equal 270, empty.content_height
    assert_equal 470, populated.content_height
    assert_equal empty.headers_height + 270, empty.pane_height
    assert_equal populated.headers_height + 470, populated.pane_height
  end

  test 'monthly periods cross a year boundary and include leap February' do
    layout = chart_layout(
      date_from: Date.new(2023, 12, 1), date_to: Date.new(2024, 2, 29), months: 3, zoom: 3
    )
    periods = layout.months

    assert_equal [Date.new(2023, 12, 1), Date.new(2024, 1, 1), Date.new(2024, 2, 1)], periods.map(&:date)
    # December, January, and leap February have 31, 31, and 29 days, at 8 pixels per day.
    assert_equal [248, 248, 232], periods.map(&:width)
    assert_equal layout.chart_width, periods.sum(&:width)
    assert_equal [false, false, true], periods.map(&:last)
    assert_equal [false, false, false], periods.map(&:spans_body)
  end

  test 'monthly periods extend through the body at zoom level one' do
    assert_equal [true], chart_layout(zoom: 1).months.map(&:spans_body)
  end

  test 'weeks beginning on Monday have no leading gap and clip the final week' do
    layout = chart_layout(date_from: Date.new(2026, 6, 1), zoom: 2)
    periods = layout.weeks

    assert_equal [1, 8, 15, 22, 29].map {|day| Date.new(2026, 6, day)}, periods.map(&:date)
    assert_equal [28, 28, 28, 28, 8], periods.map(&:width)
    assert_equal layout.chart_width, periods.sum(&:width)
    assert_equal [false, false, false, false, true], periods.map(&:last)
    assert_equal [true, true, true, true, true], periods.map(&:spans_body)
  end

  test 'weeks beginning after Monday include a leading partial week' do
    layout = chart_layout(date_from: Date.new(2026, 9, 1), zoom: 3)
    periods = layout.weeks

    assert_equal [nil, Date.new(2026, 9, 7), Date.new(2026, 9, 14), Date.new(2026, 9, 21), Date.new(2026, 9, 28)], periods.map(&:date)
    assert_equal [48, 56, 56, 56, 24], periods.map(&:width)
    assert_equal layout.chart_width, periods.sum(&:width)
    assert_equal [false, false, false, false, true], periods.map(&:last)
    assert_equal [false, false, false, false, false], periods.map(&:spans_body)
  end

  test 'weeks ending on Sunday retain a full final week' do
    layout = chart_layout(date_from: Date.new(2021, 2, 1), zoom: 2)
    periods = layout.weeks

    assert_equal [1, 8, 15, 22].map {|day| Date.new(2021, 2, day)}, periods.map(&:date)
    assert_equal [28, 28, 28, 28], periods.map(&:width)
    assert_equal layout.chart_width, periods.sum(&:width)
    assert_equal [false, false, false, true], periods.map(&:last)
  end

  test 'weeks are empty at zoom level one' do
    assert_empty chart_layout(zoom: 1).weeks
  end

  test 'day numbers include every date and its working day status' do
    layout = chart_layout(date_from: Date.new(2024, 2, 1), zoom: 4)
    periods = layout.day_numbers

    assert_equal (1..29).map {|day| Date.new(2024, 2, day)}, periods.map(&:date)
    assert_equal [16] * 29, periods.map(&:width)
    assert_equal [3, 4, 10, 11, 17, 18, 24, 25], periods.select(&:non_working).map {|period| period.date.day}
    assert_equal [false] * 28 + [true], periods.map(&:last)
    assert_equal [false] * 29, periods.map(&:spans_body)
    assert_equal layout.chart_width, periods.sum(&:width)
  end

  test 'day numbers are empty at zoom level three' do
    assert_empty chart_layout(zoom: 3).day_numbers
  end

  test 'days extend through the body and respect configured non-working weekdays' do
    layout = chart_layout(date_from: Date.new(2026, 9, 1), non_working_week_days: [2])
    periods = layout.days

    assert_equal (1..30).map {|day| Date.new(2026, 9, day)}, periods.map(&:date)
    assert_equal [8] * 30, periods.map(&:width)
    assert_equal [1, 8, 15, 22, 29], periods.select(&:non_working).map {|period| period.date.day}
    assert_equal [false] * 29 + [true], periods.map(&:last)
    assert_equal [true] * 30, periods.map(&:spans_body)
    assert_equal layout.chart_width, periods.sum(&:width)
  end

  test 'days are empty at zoom level two' do
    assert_empty chart_layout(zoom: 2).days
  end

  test 'today line marks the right edge of the current day including range endpoints' do
    layout = chart_layout(date_from: Date.new(2024, 2, 1))

    [
      [Date.new(2024, 2, 1), 7],
      [Date.new(2024, 2, 15), 119],
      [Date.new(2024, 2, 29), 231]
    ].each do |today, position|
      User.current.stubs(:today).returns(today)
      assert_equal position, layout.today_start
    end
  end

  test 'today line is absent outside the displayed range' do
    layout = chart_layout(date_from: Date.new(2024, 2, 1))

    [Date.new(2024, 1, 31), Date.new(2024, 3, 1)].each do |today|
      User.current.stubs(:today).returns(today)
      assert_nil layout.today_start
    end
  end

  private

  def chart_layout(date_from: Date.new(2026, 6, 1), date_to: date_from.end_of_month,
                   months: 1, zoom: 3, number_of_rows: 0, non_working_week_days: [6, 7])
    gantt = stub(
      date_from: date_from, date_to: date_to, months: months, zoom: zoom,
      number_of_rows: number_of_rows, non_working_week_days: non_working_week_days
    )
    GanttHelper::ChartLayout.new(gantt)
  end
end
