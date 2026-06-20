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
  class TimeEntriesController < BaseController
    before_action :find_time_entries

    def index
      @activities = @projects.map(&:activities).reduce(:&)

      edit_allowed = @time_entries.all? {|t| t.editable_by?(User.current)}
      @can = {:edit => edit_allowed, :delete => edit_allowed}
      @back = back_url

      @options_by_custom_field = {}
      if @can[:edit]
        custom_fields = @time_entries.map(&:editable_custom_fields).reduce(:&).reject(&:multiple?).select {|field| field.format.bulk_edit_supported}
        custom_fields.each do |field|
          values = field.possible_values_options(@projects)
          if values.present?
            @options_by_custom_field[field] = values
          end
        end
      end

      render_context_menu 'time_entries'
    end

    private

    def find_time_entries
      @time_entries = TimeEntry.where(:id => params[:ids]).
        preload(:project => :time_entry_activities).
        preload(:user).to_a

      if @time_entries.blank? || !@time_entries.all?(&:visible?)
        render_404;
        return
      end

      if @time_entries.size == 1
        @time_entry = @time_entries.first
      end

      @projects = @time_entries.filter_map(&:project).uniq
      @project = @projects.first if @projects.size == 1
    end
  end
end
