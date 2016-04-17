# Redmine - project management software
# Copyright (C) 2006-2016  Jean-Philippe Lang
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

class TrackersController < ApplicationController
  layout 'admin'

  before_filter :require_admin, :except => :index
  before_filter :require_admin_or_api_request, :only => :index
  accept_api_auth :index

  def index
    @trackers = Tracker.sorted.to_a
    respond_to do |format|
      format.html { render :layout => false if request.xhr? }
      format.api
    end
  end

  def new
    @tracker ||= Tracker.new(params[:tracker])
    @trackers = Tracker.sorted.to_a
    @projects = Project.all
  end

  def create
    @tracker = Tracker.new(params[:tracker])
    if @tracker.save
      # workflow copy
      if !params[:copy_workflow_from].blank? && (copy_from = Tracker.find_by_id(params[:copy_workflow_from]))
        @tracker.workflow_rules.copy(copy_from)
      end
      flash[:notice] = l(:notice_successful_create)
      redirect_to trackers_path
      return
    end
    new
    render :action => 'new'
  end

  def edit
    @tracker ||= Tracker.find(params[:id])
    @projects = Project.all
  end

  def update
    @tracker = Tracker.find(params[:id])
    if @tracker.update_attributes(params[:tracker])
      respond_to do |format|
        format.html {
          flash[:notice] = l(:notice_successful_update)
          redirect_to trackers_path(:page => params[:page])
        }
        format.js { render :nothing => true }
      end
    else
      respond_to do |format|
        format.html {
          edit
          render :action => 'edit'
        }
        format.js { render :nothing => true, :status => 422 }
      end
    end
  end

  def destroy
    @tracker = Tracker.find(params[:id])
    unless @tracker.issues.empty?
      flash[:error] = l(:error_can_not_delete_tracker)
    else
      @tracker.destroy
    end
    redirect_to trackers_path
  end

  def fields
    if request.post? && params[:trackers]
      params[:trackers].each do |tracker_id, tracker_params|
        tracker = Tracker.find_by_id(tracker_id)
        if tracker
          tracker.core_fields = tracker_params[:core_fields]
          tracker.custom_field_ids = tracker_params[:custom_field_ids]
          tracker.save
        end
      end
      flash[:notice] = l(:notice_successful_update)
      redirect_to fields_trackers_path
      return
    end
    @trackers = Tracker.sorted.to_a
    @custom_fields = IssueCustomField.all.sort
  end
end
