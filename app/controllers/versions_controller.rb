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

class VersionsController < ApplicationController
  menu_item :roadmap
  model_object Version
  before_filter :find_model_object, :except => [:index, :new, :create, :close_completed]
  before_filter :find_project_from_association, :except => [:index, :new, :create, :close_completed]
  before_filter :find_project_by_project_id, :only => [:index, :new, :create, :close_completed]
  before_filter :authorize

  accept_api_auth :index, :show, :create, :update, :destroy

  helper :custom_fields
  helper :projects

  def index
    respond_to do |format|
      format.html {
        @trackers = @project.trackers.sorted.to_a
        retrieve_selected_tracker_ids(@trackers, @trackers.select {|t| t.is_in_roadmap?})
        @with_subprojects = params[:with_subprojects].nil? ? Setting.display_subprojects_issues? : (params[:with_subprojects] == '1')
        project_ids = @with_subprojects ? @project.self_and_descendants.collect(&:id) : [@project.id]

        @versions = @project.shared_versions || []
        @versions += @project.rolled_up_versions.visible if @with_subprojects
        @versions = @versions.uniq.sort
        unless params[:completed]
          @completed_versions = @versions.select {|version| version.closed? || version.completed? }
          @versions -= @completed_versions
        end

        @issues_by_version = {}
        if @selected_tracker_ids.any? && @versions.any?
          issues = Issue.visible.
            includes(:project, :tracker).
            preload(:status, :priority, :fixed_version).
            where(:tracker_id => @selected_tracker_ids, :project_id => project_ids, :fixed_version_id => @versions.map(&:id)).
            order("#{Project.table_name}.lft, #{Tracker.table_name}.position, #{Issue.table_name}.id")
          @issues_by_version = issues.group_by(&:fixed_version)
        end
        @versions.reject! {|version| !project_ids.include?(version.project_id) && @issues_by_version[version].blank?}
      }
      format.api {
        @versions = @project.shared_versions.to_a
      }
    end
  end

  def show
    respond_to do |format|
      format.html {
        @issues = @version.fixed_issues.visible.
          includes(:status, :tracker, :priority).
          reorder("#{Tracker.table_name}.position, #{Issue.table_name}.id").
          to_a
      }
      format.api
    end
  end

  def new
    @version = @project.versions.build
    @version.safe_attributes = params[:version]

    respond_to do |format|
      format.html
      format.js
    end
  end

  def create
    @version = @project.versions.build
    if params[:version]
      attributes = params[:version].dup
      attributes.delete('sharing') unless attributes.nil? || @version.allowed_sharings.include?(attributes['sharing'])
      @version.safe_attributes = attributes
    end

    if request.post?
      if @version.save
        respond_to do |format|
          format.html do
            flash[:notice] = l(:notice_successful_create)
            redirect_back_or_default settings_project_path(@project, :tab => 'versions')
          end
          format.js
          format.api do
            render :action => 'show', :status => :created, :location => version_url(@version)
          end
        end
      else
        respond_to do |format|
          format.html { render :action => 'new' }
          format.js   { render :action => 'new' }
          format.api  { render_validation_errors(@version) }
        end
      end
    end
  end

  def edit
  end

  def update
    if params[:version]
      attributes = params[:version].dup
      attributes.delete('sharing') unless @version.allowed_sharings.include?(attributes['sharing'])
      @version.safe_attributes = attributes
      if @version.save
        respond_to do |format|
          format.html {
            flash[:notice] = l(:notice_successful_update)
            redirect_back_or_default settings_project_path(@project, :tab => 'versions')
          }
          format.api  { render_api_ok }
        end
      else
        respond_to do |format|
          format.html { render :action => 'edit' }
          format.api  { render_validation_errors(@version) }
        end
      end
    end
  end

  def close_completed
    if request.put?
      @project.close_completed_versions
    end
    redirect_to settings_project_path(@project, :tab => 'versions')
  end

  def destroy
    if @version.deletable?
      @version.destroy
      respond_to do |format|
        format.html { redirect_back_or_default settings_project_path(@project, :tab => 'versions') }
        format.api  { render_api_ok }
      end
    else
      respond_to do |format|
        format.html {
          flash[:error] = l(:notice_unable_delete_version)
          redirect_to settings_project_path(@project, :tab => 'versions')
        }
        format.api  { head :unprocessable_entity }
      end
    end
  end

  def status_by
    respond_to do |format|
      format.html { render :action => 'show' }
      format.js
    end
  end

  private

  def retrieve_selected_tracker_ids(selectable_trackers, default_trackers=nil)
    if ids = params[:tracker_ids]
      @selected_tracker_ids = (ids.is_a? Array) ? ids.collect { |id| id.to_i.to_s } : ids.split('/').collect { |id| id.to_i.to_s }
    else
      @selected_tracker_ids = (default_trackers || selectable_trackers).collect {|t| t.id.to_s }
    end
  end
end
