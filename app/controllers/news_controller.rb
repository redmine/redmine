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

class NewsController < ApplicationController
  default_search_scope :news
  model_object News
  before_action :find_model_object, :except => [:new, :create, :index]
  before_action :find_project_from_association, :except => [:new, :create, :index]
  before_action :find_project_by_project_id, :only => [:new, :create]
  before_action :authorize, :except => [:index]
  before_action :find_optional_project, :only => :index
  accept_rss_auth :index
  accept_api_auth :index

  helper :watchers
  helper :attachments

  def index
    case params[:format]
    when 'xml', 'json'
      @offset, @limit = api_offset_and_limit
    else
      @limit =  10
    end

    scope = @project ? @project.news.visible : News.visible

    @news_count = scope.count
    @news_pages = Paginator.new @news_count, @limit, params['page']
    @offset ||= @news_pages.offset
    @newss = scope.includes([:author, :project]).
                      order("#{News.table_name}.created_on DESC").
                      limit(@limit).
                      offset(@offset).
                      to_a
    respond_to do |format|
      format.html {
        @news = News.new # for adding news inline
        render :layout => false if request.xhr?
      }
      format.api
      format.atom { render_feed(@newss, :title => (@project ? @project.name : Setting.app_title) + ": #{l(:label_news_plural)}") }
    end
  end

  def show
    @comments = @news.comments.to_a
    @comments.reverse! if User.current.wants_comments_in_reverse_order?
  end

  def new
    @news = News.new(:project => @project, :author => User.current)
  end

  def create
    @news = News.new(:project => @project, :author => User.current)
    @news.safe_attributes = params[:news]
    @news.save_attachments(params[:attachments])
    if @news.save
      render_attachment_warning_if_needed(@news)
      flash[:notice] = l(:notice_successful_create)
      redirect_to project_news_index_path(@project)
    else
      render :action => 'new'
    end
  end

  def edit
  end

  def update
    @news.safe_attributes = params[:news]
    @news.save_attachments(params[:attachments])
    if @news.save
      render_attachment_warning_if_needed(@news)
      flash[:notice] = l(:notice_successful_update)
      redirect_to news_path(@news)
    else
      render :action => 'edit'
    end
  end

  def destroy
    @news.destroy
    redirect_to project_news_index_path(@project)
  end
end
