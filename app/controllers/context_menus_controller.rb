# Redmine - project management software
# Copyright (C) 2006-2013  Jean-Philippe Lang
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

  before_filter :find_issues, :only => :issues

  def issues
    if (@issues.size == 1)
      @issue = @issues.first
    end
    @issue_ids = @issues.map(&:id).sort

    @allowed_statuses = @issues.map(&:new_statuses_allowed_to).reduce(:&)

    @can = {:edit => User.current.allowed_to?(:edit_issues, @projects),
            :log_time => (@project && User.current.allowed_to?(:log_time, @project)),
            :update => (User.current.allowed_to?(:edit_issues, @projects) || (User.current.allowed_to?(:change_status, @projects) && !@allowed_statuses.blank?)),
            :move => (@project && User.current.allowed_to?(:move_issues, @project)),
            :copy => (@issue && @project.trackers.include?(@issue.tracker) && User.current.allowed_to?(:add_issues, @project)),
            :delete => User.current.allowed_to?(:delete_issues, @projects)
            }
    if @project
      if @issue
        @assignables = @issue.assignable_users
      else
        @assignables = @project.assignable_users
      end
      @trackers = @project.trackers
    else
      #when multiple projects, we only keep the intersection of each set
      @assignables = @projects.map(&:assignable_users).reduce(:&)
      @trackers = @projects.map(&:trackers).reduce(:&)
    end
    @versions = @projects.map {|p| p.shared_versions.open}.reduce(:&)

    @priorities = IssuePriority.active.reverse
    @back = back_url

    @options_by_custom_field = {}
    if @can[:edit]
      custom_fields = @issues.map(&:available_custom_fields).reduce(:&).select do |f|
        %w(bool list user version).include?(f.field_format) && !f.multiple?
      end
      custom_fields.each do |field|
        values = field.possible_values_options(@projects)
        if values.any?
          @options_by_custom_field[field] = values
        end
      end
    end

    @safe_attributes = @issues.map(&:safe_attribute_names).reduce(:&)
    render :layout => false
  end

  def time_entries
    @time_entries = TimeEntry.where(:id => params[:ids]).preload(:project).to_a
    (render_404; return) unless @time_entries.present?

    @projects = @time_entries.collect(&:project).compact.uniq
    @project = @projects.first if @projects.size == 1
    @activities = TimeEntryActivity.shared.active
    @can = {:edit   => User.current.allowed_to?(:edit_time_entries, @projects),
            :delete => User.current.allowed_to?(:edit_time_entries, @projects)
            }
    @back = back_url
    render :layout => false
  end
end
