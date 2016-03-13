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

require File.expand_path('../../../test_helper', __FILE__)

class RoutingRepositoriesTest < Redmine::RoutingTest
  def setup
    @path_hash  = repository_path_hash(%w[path to file.c])
    assert_equal "path/to/file.c", @path_hash[:path]
    assert_equal "path/to/file.c", @path_hash[:param]
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
    should_route 'GET /projects/foo/repository/statistics' => 'repositories#stats', :id => 'foo'
    should_route 'GET /projects/foo/repository/graph' => 'repositories#graph', :id => 'foo'
  end

  def test_repositories_with_repository_id
    should_route 'GET /projects/foo/repository/svn' => 'repositories#show', :id => 'foo', :repository_id => 'svn'
    should_route 'GET /projects/foo/repository/svn/statistics' => 'repositories#stats', :id => 'foo', :repository_id => 'svn'
    should_route 'GET /projects/foo/repository/svn/graph' => 'repositories#graph', :id => 'foo', :repository_id => 'svn'
  end

  def test_repositories_revisions
    should_route 'GET /projects/foo/repository/revision' => 'repositories#revision', :id => 'foo'
    should_route 'GET /projects/foo/repository/revisions' => 'repositories#revisions', :id => 'foo'
    should_route 'GET /projects/foo/repository/revisions.atom' => 'repositories#revisions', :id => 'foo', :format => 'atom'

    should_route 'GET /projects/foo/repository/revisions/2457' => 'repositories#revision', :id => 'foo', :rev => '2457'
    should_route 'GET /projects/foo/repository/revisions/2457/show' => 'repositories#show', :id => 'foo', :rev => '2457'
    should_route 'GET /projects/foo/repository/revisions/2457/diff' => 'repositories#diff', :id => 'foo', :rev => '2457'

    should_route "GET /projects/foo/repository/revisions/2457/show/#{@path_hash[:path]}" => 'repositories#show',
      :id => 'foo', :rev => '2457', :path => @path_hash[:param]
    should_route "GET /projects/foo/repository/revisions/2457/diff/#{@path_hash[:path]}" => 'repositories#diff',
      :id => 'foo', :rev => '2457', :path => @path_hash[:param]
    should_route "GET /projects/foo/repository/revisions/2457/entry/#{@path_hash[:path]}" => 'repositories#entry',
      :id => 'foo', :rev => '2457', :path => @path_hash[:param]
    should_route "GET /projects/foo/repository/revisions/2457/raw/#{@path_hash[:path]}" => 'repositories#raw',
      :id => 'foo', :rev => '2457', :path => @path_hash[:param]
    should_route "GET /projects/foo/repository/revisions/2457/annotate/#{@path_hash[:path]}" => 'repositories#annotate',
      :id => 'foo', :rev => '2457', :path => @path_hash[:param]
  end

  def test_repositories_revisions_with_repository_id
    should_route 'GET /projects/foo/repository/foo/revision' => 'repositories#revision', :id => 'foo', :repository_id => 'foo'
    should_route 'GET /projects/foo/repository/foo/revisions' => 'repositories#revisions', :id => 'foo', :repository_id => 'foo'
    should_route 'GET /projects/foo/repository/foo/revisions.atom' => 'repositories#revisions', :id => 'foo', :repository_id => 'foo', :format => 'atom'

    should_route 'GET /projects/foo/repository/foo/revisions/2457' => 'repositories#revision', :id => 'foo', :repository_id => 'foo', :rev => '2457'
    should_route 'GET /projects/foo/repository/foo/revisions/2457/show' => 'repositories#show', :id => 'foo', :repository_id => 'foo', :rev => '2457'
    should_route 'GET /projects/foo/repository/foo/revisions/2457/diff' => 'repositories#diff', :id => 'foo', :repository_id => 'foo', :rev => '2457'

    should_route "GET /projects/foo/repository/foo/revisions/2457/show/#{@path_hash[:path]}" => 'repositories#show',
      :id => 'foo', :repository_id => 'foo', :rev => '2457', :path => @path_hash[:param]
    should_route "GET /projects/foo/repository/foo/revisions/2457/diff/#{@path_hash[:path]}" => 'repositories#diff',
      :id => 'foo', :repository_id => 'foo', :rev => '2457', :path => @path_hash[:param]
    should_route "GET /projects/foo/repository/foo/revisions/2457/entry/#{@path_hash[:path]}" => 'repositories#entry',
      :id => 'foo', :repository_id => 'foo', :rev => '2457', :path => @path_hash[:param]
    should_route "GET /projects/foo/repository/foo/revisions/2457/raw/#{@path_hash[:path]}" => 'repositories#raw',
      :id => 'foo', :repository_id => 'foo', :rev => '2457', :path => @path_hash[:param]
    should_route "GET /projects/foo/repository/foo/revisions/2457/annotate/#{@path_hash[:path]}" => 'repositories#annotate',
      :id => 'foo', :repository_id => 'foo', :rev => '2457', :path => @path_hash[:param]
  end

  def test_repositories_non_revisions_path
    should_route 'GET /projects/foo/repository/changes' => 'repositories#changes', :id => 'foo'

    should_route "GET /projects/foo/repository/changes/#{@path_hash[:path]}" => 'repositories#changes',
      :id => 'foo', :path => @path_hash[:param]
    should_route "GET /projects/foo/repository/diff/#{@path_hash[:path]}" => 'repositories#diff',
      :id => 'foo', :path => @path_hash[:param]
    should_route "GET /projects/foo/repository/browse/#{@path_hash[:path]}" => 'repositories#browse',
      :id => 'foo', :path => @path_hash[:param]
    should_route "GET /projects/foo/repository/entry/#{@path_hash[:path]}" => 'repositories#entry',
      :id => 'foo', :path => @path_hash[:param]
    should_route "GET /projects/foo/repository/raw/#{@path_hash[:path]}" => 'repositories#raw',
      :id => 'foo', :path => @path_hash[:param]
    should_route "GET /projects/foo/repository/annotate/#{@path_hash[:path]}" => 'repositories#annotate',
      :id => 'foo', :path => @path_hash[:param]
  end

  def test_repositories_non_revisions_path_with_repository_id
    should_route 'GET /projects/foo/repository/svn/changes' => 'repositories#changes', :id => 'foo', :repository_id => 'svn'

    should_route "GET /projects/foo/repository/svn/changes/#{@path_hash[:path]}" => 'repositories#changes',
      :id => 'foo', :repository_id => 'svn', :path => @path_hash[:param]
    should_route "GET /projects/foo/repository/svn/diff/#{@path_hash[:path]}" => 'repositories#diff',
      :id => 'foo', :repository_id => 'svn', :path => @path_hash[:param]
    should_route "GET /projects/foo/repository/svn/browse/#{@path_hash[:path]}" => 'repositories#browse',
      :id => 'foo', :repository_id => 'svn', :path => @path_hash[:param]
    should_route "GET /projects/foo/repository/svn/entry/#{@path_hash[:path]}" => 'repositories#entry',
      :id => 'foo', :repository_id => 'svn', :path => @path_hash[:param]
    should_route "GET /projects/foo/repository/svn/raw/#{@path_hash[:path]}" => 'repositories#raw',
      :id => 'foo', :repository_id => 'svn', :path => @path_hash[:param]
    should_route "GET /projects/foo/repository/svn/annotate/#{@path_hash[:path]}" => 'repositories#annotate',
      :id => 'foo', :repository_id => 'svn', :path => @path_hash[:param]
  end

  def test_repositories_related_issues
    should_route 'POST /projects/foo/repository/revisions/123/issues' => 'repositories#add_related_issue',
      :id => 'foo', :rev => '123'
    should_route 'DELETE /projects/foo/repository/revisions/123/issues/25' => 'repositories#remove_related_issue',
      :id => 'foo', :rev => '123', :issue_id => '25'
  end

  def test_repositories_related_issues_with_repository_id
    should_route 'POST /projects/foo/repository/svn/revisions/123/issues' => 'repositories#add_related_issue',
      :id => 'foo', :repository_id => 'svn', :rev => '123'
    should_route 'DELETE /projects/foo/repository/svn/revisions/123/issues/25' => 'repositories#remove_related_issue',
      :id => 'foo', :repository_id => 'svn', :rev => '123', :issue_id => '25'
  end
end
