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

module NonWorkingDatesHelper
  def non_working_dates_to_csv(non_working_dates)
    Redmine::Export::CSV.generate(:encoding => params[:encoding], :field_separator => params[:field_separator]) do |csv|
      csv << [l(:field_date), l(:field_name)]
      non_working_dates.each do |non_working_date|
        csv << [format_date(non_working_date.date), non_working_date.name]
      end
    end
  end
end
