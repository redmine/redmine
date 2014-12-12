# Redmine - project management software
# Copyright (C) 2006-2014  Jean-Philippe Lang
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
  before_filter :find_optional_project

  def index
    @question = params[:q] || ""
    @question.strip!
    @all_words = params[:all_words] ? params[:all_words].present? : true
    @titles_only = params[:titles_only] ? params[:titles_only].present? : false

    projects_to_search =
      case params[:scope]
      when 'all'
        nil
      when 'my_projects'
        User.current.memberships.collect(&:project)
      when 'subprojects'
        @project ? (@project.self_and_descendants.active.to_a) : nil
      else
        @project
      end

    # quick jump to an issue
    if (m = @question.match(/^#?(\d+)$/)) && (issue = Issue.visible.find_by_id(m[1].to_i))
      redirect_to issue_path(issue)
      return
    end

    @object_types = Redmine::Search.available_search_types.dup
    if projects_to_search.is_a? Project
      # don't search projects
      @object_types.delete('projects')
      # only show what the user is allowed to view
      @object_types = @object_types.select {|o| User.current.allowed_to?("view_#{o}".to_sym, projects_to_search)}
    end

    @scope = @object_types.select {|t| params[t]}
    @scope = @object_types if @scope.empty?

    # extract tokens from the question
    # eg. hello "bye bye" => ["hello", "bye bye"]
    @tokens = @question.scan(%r{((\s|^)"[\s\w]+"(\s|$)|\S+)}).collect {|m| m.first.gsub(%r{(^\s*"\s*|\s*"\s*$)}, '')}
    # tokens must be at least 2 characters long
    @tokens = @tokens.uniq.select {|w| w.length > 1 }

    if !@tokens.empty?
      # no more than 5 tokens to search for
      @tokens.slice! 5..-1 if @tokens.size > 5

      limit = 10

      @result_count = 0
      @result_count_by_type = Hash.new {|h,k| h[k] = 0}
      ranks_and_ids = []

      # get all the results ranks and ids
      @scope.each do |scope|
        klass = scope.singularize.camelcase.constantize
        ranks_and_ids_in_scope = klass.search_result_ranks_and_ids(@tokens, User.current, projects_to_search,
          :all_words => @all_words,
          :titles_only => @titles_only
        )
        @result_count_by_type[scope] += ranks_and_ids_in_scope.size
        @result_count += ranks_and_ids_in_scope.size
        ranks_and_ids += ranks_and_ids_in_scope.map {|r| [scope, r]}
      end
      @result_pages = Paginator.new @result_count, limit, params['page']

      # sort results, higher rank and id first
      ranks_and_ids.sort! {|a,b| b.last <=> a.last }
      ranks_and_ids = ranks_and_ids[@result_pages.offset, limit] || []

      # load the results to display
      results_by_scope = Hash.new {|h,k| h[k] = []}
      ranks_and_ids.group_by(&:first).each do |scope, rs|
        klass = scope.singularize.camelcase.constantize
        results_by_scope[scope] += klass.search_results_from_ids(rs.map(&:last).map(&:last))
      end

      @results = ranks_and_ids.map do |scope, r|
        results_by_scope[scope].detect {|record| record.id == r.last}
      end.compact
    else
      @question = ""
    end
    render :layout => false if request.xhr?
  end

private
  def find_optional_project
    return true unless params[:id]
    @project = Project.find(params[:id])
    check_project_privacy
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
