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

class WorkflowsController < ApplicationController
  layout 'admin'

  before_filter :require_admin, :find_roles, :find_trackers

  def index
    @workflow_counts = WorkflowTransition.count_by_tracker_and_role
  end

  def edit
    @role = Role.find_by_id(params[:role_id]) if params[:role_id]
    @tracker = Tracker.find_by_id(params[:tracker_id]) if params[:tracker_id]

    if request.post?
      WorkflowTransition.destroy_all( ["role_id=? and tracker_id=?", @role.id, @tracker.id])
      (params[:issue_status] || []).each { |status_id, transitions|
        transitions.each { |new_status_id, options|
          author = options.is_a?(Array) && options.include?('author') && !options.include?('always')
          assignee = options.is_a?(Array) && options.include?('assignee') && !options.include?('always')
          WorkflowTransition.create(:role_id => @role.id, :tracker_id => @tracker.id, :old_status_id => status_id, :new_status_id => new_status_id, :author => author, :assignee => assignee)
        }
      }
      if @role.save
        redirect_to workflows_edit_path(:role_id => @role, :tracker_id => @tracker, :used_statuses_only => params[:used_statuses_only])
        return
      end
    end

    @used_statuses_only = (params[:used_statuses_only] == '0' ? false : true)
    if @tracker && @used_statuses_only && @tracker.issue_statuses.any?
      @statuses = @tracker.issue_statuses
    end
    @statuses ||= IssueStatus.sorted.all

    if @tracker && @role && @statuses.any?
      workflows = WorkflowTransition.where(:role_id => @role.id, :tracker_id => @tracker.id).all
      @workflows = {}
      @workflows['always'] = workflows.select {|w| !w.author && !w.assignee}
      @workflows['author'] = workflows.select {|w| w.author}
      @workflows['assignee'] = workflows.select {|w| w.assignee}
    end
  end

  def permissions
    @role = Role.find_by_id(params[:role_id]) if params[:role_id]
    @tracker = Tracker.find_by_id(params[:tracker_id]) if params[:tracker_id]

    if request.post? && @role && @tracker
      WorkflowPermission.replace_permissions(@tracker, @role, params[:permissions] || {})
      redirect_to workflows_permissions_path(:role_id => @role, :tracker_id => @tracker, :used_statuses_only => params[:used_statuses_only])
      return
    end

    @used_statuses_only = (params[:used_statuses_only] == '0' ? false : true)
    if @tracker && @used_statuses_only && @tracker.issue_statuses.any?
      @statuses = @tracker.issue_statuses
    end
    @statuses ||= IssueStatus.sorted.all

    if @role && @tracker
      @fields = (Tracker::CORE_FIELDS_ALL - @tracker.disabled_core_fields).map {|field| [field, l("field_"+field.sub(/_id$/, ''))]}
      @custom_fields = @tracker.custom_fields

      @permissions = WorkflowPermission.where(:tracker_id => @tracker.id, :role_id => @role.id).all.inject({}) do |h, w|
        h[w.old_status_id] ||= {}
        h[w.old_status_id][w.field_name] = w.rule
        h
      end
      @statuses.each {|status| @permissions[status.id] ||= {}}
    end
  end

  def copy

    if params[:source_tracker_id].blank? || params[:source_tracker_id] == 'any'
      @source_tracker = nil
    else
      @source_tracker = Tracker.find_by_id(params[:source_tracker_id].to_i)
    end
    if params[:source_role_id].blank? || params[:source_role_id] == 'any'
      @source_role = nil
    else
      @source_role = Role.find_by_id(params[:source_role_id].to_i)
    end

    @target_trackers = params[:target_tracker_ids].blank? ? nil : Tracker.find_all_by_id(params[:target_tracker_ids])
    @target_roles = params[:target_role_ids].blank? ? nil : Role.find_all_by_id(params[:target_role_ids])

    if request.post?
      if params[:source_tracker_id].blank? || params[:source_role_id].blank? || (@source_tracker.nil? && @source_role.nil?)
        flash.now[:error] = l(:error_workflow_copy_source)
      elsif @target_trackers.blank? || @target_roles.blank?
        flash.now[:error] = l(:error_workflow_copy_target)
      else
        WorkflowRule.copy(@source_tracker, @source_role, @target_trackers, @target_roles)
        flash[:notice] = l(:notice_successful_update)
        redirect_to workflows_copy_path(:source_tracker_id => @source_tracker, :source_role_id => @source_role)
      end
    end
  end

  private

  def find_roles
    @roles = Role.sorted.all
  end

  def find_trackers
    @trackers = Tracker.sorted.all
  end
end
