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

require File.expand_path('../../../test_helper', __FILE__)

class RoutingRepositoriesTest < Redmine::RoutingTest

  def setup
    @paths = ['path/to/index.html',
              'path/to/file.c', 'path/to/file.yaml', 'path/to/file.txt',
              'raw/file.c']
  end

  def test_repositories_resources
    should_route 'GET /projects/foo/repositories/new' => 'repositories#new', :project_id => 'foo'
    should_route 'POST /projects/foo/repositories' => 'repositories#create', :project_id => 'foo'

    should_route 'GET /repositories/1/edit' => 'repositories#edit', :id => '1'
    should_route 'PUT /repositories/1' => 'repositories#update', :id => '1'
    should_route 'DELETE /repositories/1' => 'repositories#destroy', :id => '1'

    should_route 'GET /repositories/1/committers' => 'repositories#committers', :id => '1'
    should_route 'POST /repositories/1/committers' => 'repositories#committers', :id => '1'
  end

  def test_repositories
    should_route 'GET /projects/foo/repository' => 'repositories#show', :id => 'foo'
  end

  def test_repositories_with_repository_id
    should_route 'GET /projects/foo/repository/svn' => 'repositories#show', :id => 'foo', :repository_id => 'svn'
    should_route 'GET /projects/foo/repository/svn/statistics' => 'repositories#stats', :id => 'foo', :repository_id => 'svn'
    should_route 'GET /projects/foo/repository/svn/graph' => 'repositories#graph', :id => 'foo', :repository_id => 'svn'
  end

  def test_repositories_revisions_with_repository_id
    should_route 'GET /projects/foo/repository/foo/revision' => 'repositories#revision', :id => 'foo', :repository_id => 'foo'
    should_route 'GET /projects/foo/repository/foo/revisions' => 'repositories#revisions', :id => 'foo', :repository_id => 'foo'
    should_route 'GET /projects/foo/repository/foo/revisions.atom' => 'repositories#revisions', :id => 'foo', :repository_id => 'foo', :format => 'atom'

    should_route 'GET /projects/foo/repository/foo/revisions/2457' => 'repositories#revision', :id => 'foo', :repository_id => 'foo', :rev => '2457'
    should_route 'GET /projects/foo/repository/foo/revisions/2457/show' => 'repositories#show', :id => 'foo', :repository_id => 'foo', :rev => '2457', :format => 'html'
    should_route 'GET /projects/foo/repository/foo/revisions/2457/diff' => 'repositories#diff', :id => 'foo', :repository_id => 'foo', :rev => '2457'

    %w(show entry raw annotate).each do |action|
      @paths.each do |path|
        should_route "GET /projects/foo/repository/foo/revisions/2457/#{action}/#{path}" => "repositories##{action}",
          :id => 'foo', :repository_id => 'foo', :rev => '2457', :path => path, :format => 'html'
      end
    end
    @paths.each do |path|
      should_route "GET /projects/foo/repository/foo/revisions/2457/diff/#{path}" => "repositories#diff",
        :id => 'foo', :repository_id => 'foo', :rev => '2457', :path => path
    end
  end

  def test_repositories_fetch_changesets_with_repository_id
    should_route 'POST /projects/foo/repository/bar/fetch_changesets' => 'repositories#fetch_changesets', :id => 'foo', :repository_id => 'bar'
  end

  def test_repositories_non_revisions_path_with_repository_id
    should_route 'GET /projects/foo/repository/svn/changes' => 'repositories#changes', :id => 'foo', :repository_id => 'svn', :format => 'html'

    %w(changes browse entry raw annotate).each do |action|
      @paths.each do |path|
        should_route "GET /projects/foo/repository/svn/#{action}/#{path}" => "repositories##{action}",
          :id => 'foo', :repository_id => 'svn', :path => path, :format => 'html'
      end
    end
    @paths.each do |path|
      should_route "GET /projects/foo/repository/svn/diff/#{path}" => "repositories#diff",
        :id => 'foo', :repository_id => 'svn', :path => path
    end
  end

  def test_repositories_related_issues_with_repository_id
    should_route 'POST /projects/foo/repository/svn/revisions/123/issues' => 'repositories#add_related_issue',
      :id => 'foo', :repository_id => 'svn', :rev => '123'
    should_route 'DELETE /projects/foo/repository/svn/revisions/123/issues/25' => 'repositories#remove_related_issue',
      :id => 'foo', :repository_id => 'svn', :rev => '123', :issue_id => '25'
  end
end
