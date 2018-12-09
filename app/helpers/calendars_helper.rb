# encoding: utf-8
#
# Redmine - project management software
# Copyright (C) 2006-2017  Jean-Philippe Lang
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

module CalendarsHelper
  def link_to_previous_month(year, month, options={})
    target_year, target_month = if month == 1
                                  [year - 1, 12]
                                else
                                  [year, month - 1]
                                end

    name = if target_month == 12
             "#{month_name(target_month)} #{target_year}"
           else
             "#{month_name(target_month)}"
           end

    # \xc2\xab(utf-8) = &#171;
    link_to_month(("\xc2\xab " + name), target_year, target_month, options)
  end

  def link_to_next_month(year, month, options={})
    target_year, target_month = if month == 12
                                  [year + 1, 1]
                                else
                                  [year, month + 1]
                                end

    name = if target_month == 1
             "#{month_name(target_month)} #{target_year}"
           else
             "#{month_name(target_month)}"
           end

    # \xc2\xbb(utf-8) = &#187;
    link_to_month((name + " \xc2\xbb"), target_year, target_month, options)
  end

  def link_to_month(link_name, year, month, options={})
    link_to(link_name, {:params => request.query_parameters.merge(:year => year, :month => month)}, options)
  end
end
