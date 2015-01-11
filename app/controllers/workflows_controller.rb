# Redmine - project management software
# Copyright (C) 2006-2015  Jean-Philippe Lang
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

  before_filter :require_admin

  def index
    @roles = Role.sorted.select(&:consider_workflow?)
    @trackers = Tracker.sorted
    @workflow_counts = WorkflowTransition.group(:tracker_id, :role_id).count
  end

  def edit
    find_trackers_roles_and_statuses_for_edit

    if request.post? && @roles && @trackers && params[:transitions]
      transitions = params[:transitions].deep_dup
      transitions.each do |old_status_id, transitions_by_new_status|
        transitions_by_new_status.each do |new_status_id, transition_by_rule|
          transition_by_rule.reject! {|rule, transition| transition == 'no_change'}
        end
      end
      WorkflowTransition.replace_transitions(@trackers, @roles, transitions)
      flash[:notice] = l(:notice_successful_update)
      redirect_to_referer_or workflows_edit_path
      return
    end

    if @trackers && @roles && @statuses.any?
      workflows = WorkflowTransition.where(:role_id => @roles.map(&:id), :tracker_id => @trackers.map(&:id))
      @workflows = {}
      @workflows['always'] = workflows.select {|w| !w.author && !w.assignee}
      @workflows['author'] = workflows.select {|w| w.author}
      @workflows['assignee'] = workflows.select {|w| w.assignee}
    end
  end

  def permissions
    find_trackers_roles_and_statuses_for_edit

    if request.post? && @roles && @trackers && params[:permissions]
      permissions = params[:permissions].deep_dup
      permissions.each { |field, rule_by_status_id|
        rule_by_status_id.reject! {|status_id, rule| rule == 'no_change'}
      }
      WorkflowPermission.replace_permissions(@trackers, @roles, permissions)
      flash[:notice] = l(:notice_successful_update)
      redirect_to_referer_or workflows_permissions_path
      return
    end

    if @roles && @trackers
      @fields = (Tracker::CORE_FIELDS_ALL - @trackers.map(&:disabled_core_fields).reduce(:&)).map {|field| [field, l("field_"+field.sub(/_id$/, ''))]}
      @custom_fields = @trackers.map(&:custom_fields).flatten.uniq.sort
      @permissions = WorkflowPermission.rules_by_status_id(@trackers, @roles)
      @statuses.each {|status| @permissions[status.id] ||= {}}
    end
  end

  def copy
    @roles = Role.sorted.select(&:consider_workflow?)
    @trackers = Tracker.sorted

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
    @target_trackers = params[:target_tracker_ids].blank? ?
        nil : Tracker.where(:id => params[:target_tracker_ids]).to_a
    @target_roles = params[:target_role_ids].blank? ?
        nil : Role.where(:id => params[:target_role_ids]).to_a
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

  def find_trackers_roles_and_statuses_for_edit
    find_roles
    find_trackers
    find_statuses
  end

  def find_roles
    ids = Array.wrap(params[:role_id])
    if ids == ['all']
      @roles = Role.sorted.to_a
    elsif ids.present?
      @roles = Role.where(:id => ids).to_a
    end
    @roles = nil if @roles.blank?
  end

  def find_trackers
    ids = Array.wrap(params[:tracker_id])
    if ids == ['all']
      @trackers = Tracker.sorted.to_a
    elsif ids.present?
      @trackers = Tracker.where(:id => ids).to_a
    end
    @trackers = nil if @trackers.blank?
  end

  def find_statuses
    @used_statuses_only = (params[:used_statuses_only] == '0' ? false : true)
    if @trackers && @used_statuses_only
      @statuses = @trackers.map(&:issue_statuses).flatten.uniq.sort.presence
    end
    @statuses ||= IssueStatus.sorted.to_a
  end
end
