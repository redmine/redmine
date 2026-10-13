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

module ContextMenus
  class NonWorkingDatesController < BaseController
    before_action :require_admin
    before_action :find_non_working_dates

    def index
      render_context_menu 'non_working_dates'
    end

    private

    def find_non_working_dates
      @non_working_dates = NonWorkingDate.where(id: params[:id] || params[:ids]).to_a
      (render_404; return) if @non_working_dates.empty?

      if @non_working_dates.size == 1
        @non_working_date = @non_working_dates.first
      end
    end
  end
end
