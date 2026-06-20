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
  class IssuesController < BaseController
    helper :watchers
    helper :issues

    before_action :find_issues, :only => :index

    def index
      issues
      render_context_menu 'issues'
    end

    private

    def issues
      if @issues.size == 1
        @issue = @issues.first
      end
      @issue_ids = @issues.map(&:id).sort

      @allowed_statuses = @issues.map(&:new_statuses_allowed_to).reduce(:&)

      @can = {
        :edit => @issues.all?(&:attributes_editable?),
        :log_time => @issue&.time_loggable?,
        :copy => User.current.allowed_to?(:copy_issues, @projects) && Issue.allowed_target_projects.any?,
        :add_watchers => User.current.allowed_to?(:add_issue_watchers, @projects),
        :delete => @issues.all?(&:deletable?),
        :add_subtask => @issue && !@issue.closed? && User.current.allowed_to?(:manage_subtasks, @project)
      }

      @assignables = @issues.map(&:assignable_users).reduce(:&)
      @trackers = @projects.map {|p| Issue.allowed_target_trackers(p)}.reduce(:&)
      @versions = @projects.map {|p| p.shared_versions.open}.reduce(:&)

      @priorities = IssuePriority.active.reverse
      @back = back_url
      begin
        # Recognize the controller and action from the back_url to determine
        # which view triggered the context menu.
        if relative_url_root.present? && back_url&.starts_with?(relative_url_root)
          normalized_back_url = back_url.delete_prefix(relative_url_root)
        else
          normalized_back_url = back_url
        end
        route = Rails.application.routes.recognize_path(normalized_back_url)
        @include_delete =
          [
            {controller: 'issues', action: 'index'},
            {controller: 'gantts', action: 'show'},
            {controller: 'calendars', action: 'show'}
          ].any?(route.slice(:controller, :action))
      rescue ActionController::RoutingError
        @include_delete = false
      end

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
    end
  end
end
