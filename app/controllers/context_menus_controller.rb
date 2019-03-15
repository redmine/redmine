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

class ContextMenusController < ApplicationController
  helper :watchers
  helper :issues

  before_action :find_issues, :only => :issues

  def issues
    if (@issues.size == 1)
      @issue = @issues.first
    end
    @issue_ids = @issues.map(&:id).sort

    @allowed_statuses = @issues.map(&:new_statuses_allowed_to).reduce(:&)

    @can = {:edit => @issues.all?(&:attributes_editable?),
            :log_time => (@project && User.current.allowed_to?(:log_time, @project)),
            :copy => User.current.allowed_to?(:copy_issues, @projects) && Issue.allowed_target_projects.any?,
            :add_watchers => User.current.allowed_to?(:add_issue_watchers, @projects),
            :delete => @issues.all?(&:deletable?)
            }

    @assignables = @issues.map(&:assignable_users).reduce(:&)
    @trackers = @projects.map {|p| Issue.allowed_target_trackers(p) }.reduce(:&)
    @versions = @projects.map {|p| p.shared_versions.open}.reduce(:&)

    @priorities = IssuePriority.active.reverse
    @back = back_url

    @columns = params[:c]

    @options_by_custom_field = {}
    if @can[:edit]
      custom_fields = @issues.map(&:editable_custom_fields).reduce(:&).reject(&:multiple?).select {|field| field.format.bulk_edit_supported}
      custom_fields.each do |field|
        values = field.possible_values_options(@projects)
        if values.present?
          @options_by_custom_field[field] = values
        end
      end
    end

    @safe_attributes = @issues.map(&:safe_attribute_names).reduce(:&)
    render :layout => false
  end

  def time_entries
    @time_entries = TimeEntry.where(:id => params[:ids]).
      preload(:project => :time_entry_activities).
      preload(:user).to_a

    (render_404; return) unless @time_entries.present?
    if (@time_entries.size == 1)
      @time_entry = @time_entries.first
    end

    @projects = @time_entries.collect(&:project).compact.uniq
    @project = @projects.first if @projects.size == 1
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

    render :layout => false
  end
end
