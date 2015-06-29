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

class QueriesController < ApplicationController
  menu_item :issues
  before_filter :find_query, :except => [:new, :create, :index]
  before_filter :find_optional_project, :only => [:new, :create]

  accept_api_auth :index

  include QueriesHelper

  def index
    case params[:format]
    when 'xml', 'json'
      @offset, @limit = api_offset_and_limit
    else
      @limit = per_page_option
    end
    @query_count = IssueQuery.visible.count
    @query_pages = Paginator.new @query_count, @limit, params['page']
    @queries = IssueQuery.visible.
                    order("#{Query.table_name}.name").
                    limit(@limit).
                    offset(@offset).
                    to_a
    respond_to do |format|
      format.html {render_error :status => 406}
      format.api
    end
  end

  def new
    @query = IssueQuery.new
    @query.user = User.current
    @query.project = @project
    @query.build_from_params(params)
  end

  def create
    @query = IssueQuery.new
    @query.user = User.current
    @query.project = @project
    update_query_from_params

    if @query.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to_issues(:query_id => @query)
    else
      render :action => 'new', :layout => !request.xhr?
    end
  end

  def edit
  end

  def update
    update_query_from_params

    if @query.save
      flash[:notice] = l(:notice_successful_update)
      redirect_to_issues(:query_id => @query)
    else
      render :action => 'edit'
    end
  end

  def destroy
    @query.destroy
    redirect_to_issues(:set_filter => 1)
  end

private
  def find_query
    @query = IssueQuery.find(params[:id])
    @project = @query.project
    render_403 unless @query.editable_by?(User.current)
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_optional_project
    @project = Project.find(params[:project_id]) if params[:project_id]
    render_403 unless User.current.allowed_to?(:save_queries, @project, :global => true)
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def update_query_from_params
    @query.project = params[:query_is_for_all] ? nil : @project
    @query.build_from_params(params)
    @query.column_names = nil if params[:default_columns]
    @query.sort_criteria = params[:query] && params[:query][:sort_criteria]
    @query.name = params[:query] && params[:query][:name]
    if User.current.allowed_to?(:manage_public_queries, @query.project) || User.current.admin?
      @query.visibility = (params[:query] && params[:query][:visibility]) || IssueQuery::VISIBILITY_PRIVATE
    else
      @query.visibility = IssueQuery::VISIBILITY_PRIVATE
    end
    @query
  end

  def redirect_to_issues(options)
    if params[:gantt]
      if @project
        redirect_to project_gantt_path(@project, options)
      else
        redirect_to issues_gantt_path(options)
      end
    else
      redirect_to _project_issues_path(@project, options)
    end
  end
end
