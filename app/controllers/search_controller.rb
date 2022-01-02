# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2022  Jean-Philippe Lang
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

class SearchController < ApplicationController
  before_action :find_optional_project_by_id, :authorize_global
  accept_api_auth :index

  def index
    @question = params[:q]&.strip || ""
    @all_words = params[:all_words] ? params[:all_words].present? : true
    @titles_only = params[:titles_only] ? params[:titles_only].present? : false
    @search_attachments = params[:attachments].presence || '0'
    @open_issues = params[:open_issues] ? params[:open_issues].present? : false

    case params[:format]
    when 'xml', 'json'
      @offset, @limit = api_offset_and_limit
    else
      @offset = nil
      @limit = Setting.search_results_per_page.to_i
      @limit = 10 if @limit == 0
    end

    # quick jump to an issue
    if !api_request? && (m = @question.match(/^#?(\d+)$/)) && (issue = Issue.visible.find_by_id(m[1].to_i))
      redirect_to issue_path(issue)
      return
    end

    projects_to_search =
      case params[:scope]
      when 'all'
        nil
      when 'my_projects'
        User.current.projects
      when 'subprojects'
        @project ? (@project.self_and_descendants.to_a) : nil
      else
        @project
      end

    @object_types = Redmine::Search.available_search_types.dup
    if projects_to_search.is_a? Project
      # don't search projects
      @object_types.delete('projects')
      # only show what the user is allowed to view
      @object_types = @object_types.select {|o| User.current.allowed_to?("view_#{o}".to_sym, projects_to_search)}
    end

    @scope = @object_types.select {|t| params[t].present?}
    @scope = @object_types if @scope.empty?

    fetcher = Redmine::Search::Fetcher.new(
      @question, User.current, @scope, projects_to_search,
      :all_words => @all_words, :titles_only => @titles_only, :attachments => @search_attachments, :open_issues => @open_issues,
      :cache => params[:page].present?, :params => params.to_unsafe_hash
    )

    if fetcher.tokens.present?
      @result_count = fetcher.result_count
      @result_count_by_type = fetcher.result_count_by_type
      @tokens = fetcher.tokens

      @result_pages = Paginator.new @result_count, @limit, params['page']
      @offset ||= @result_pages.offset
      @results = fetcher.results(@offset, @result_pages.per_page)
    else
      @question = ""
    end
    respond_to do |format|
      format.html {render :layout => false if request.xhr?}
      format.api do
        @results ||= []
        render :layout => false
      end
    end
  end
end
