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

module Redmine
  module Utils
    module DateCalculation
      # Returns the number of working days between from and to
      def working_days(from, to)
        days = (to - from).to_i
        if days > 0
          weeks = days / 7
          result = weeks * (7 - non_working_week_days.size)
          days_left = days - weeks * 7
          start_cwday = from.cwday
          days_left.times do |i|
            unless non_working_week_days.include?(((start_cwday + i - 1) % 7) + 1)
              result += 1
            end
          end
          result - non_working_dates_count(from, to)
        else
          0
        end
      end

      # Adds working days to the given date
      def add_working_days(date, working_days)
        if working_days > 0
          result = add_working_week_days(date, working_days)
          # Each registered non working date that was passed over
          # pushes the result back by one more working day
          from = date
          while (skipped = non_working_dates_count(from + 1, result + 1)) > 0
            from = result
            result = add_working_week_days(result, skipped)
          end
          next_working_date(result)
        else
          date
        end
      end

      # Returns the date of the first day on or after the given date that is a working day
      def next_working_date(date)
        date += 1 while non_working_day?(date)
        date
      end

      # Returns true if the given date is a non working day
      def non_working_day?(date)
        non_working_week_days.include?(date.cwday) || NonWorkingDate.names_by_date.key?(date)
      end

      # Returns the index of non working week days (1=monday, 7=sunday)
      def non_working_week_days
        @non_working_week_days ||= begin
          days = Setting.non_working_week_days
          if days.is_a?(Array) && days.size < 7
            days.map(&:to_i)
          else
            []
          end
        end
      end

      private

      # Adds working days to the given date,
      # taking only non working week days into account
      def add_working_week_days(date, working_days)
        weeks = working_days / (7 - non_working_week_days.size)
        result = weeks * 7
        days_left = working_days - weeks * (7 - non_working_week_days.size)
        cwday = date.cwday
        while days_left > 0
          cwday += 1
          unless non_working_week_days.include?(((cwday - 1) % 7) + 1)
            days_left -= 1
          end
          result += 1
        end
        date + result
      end

      # Returns the number of registered non working dates that are on or after from
      # and before to, and that do not fall on a non working week day
      def non_working_dates_count(from, to)
        dates = NonWorkingDate.sorted_dates
        first = dates.bsearch_index {|date| date >= from} || dates.size
        last = dates.bsearch_index {|date| date >= to} || dates.size
        dates[first...last].count {|date| non_working_week_days.exclude?(date.cwday)}
      end
    end
  end
end
