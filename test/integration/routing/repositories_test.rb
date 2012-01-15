# Redmine - project management software
# Copyright (C) 2006-2011  Jean-Philippe Lang
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

class RoutingRepositoriesTest < ActionController::IntegrationTest
  def setup
    @path_hash  = repository_path_hash(%w[path to file.c])
    assert_equal "path/to/file.c", @path_hash[:path]
    assert_equal %w[path to file.c], @path_hash[:param]
  end

  def test_repositories_resources
    assert_routing(
        { :method => 'get',
          :path => "/projects/redmine/repositories/new" },
        { :controller => 'repositories', :action => 'new', :project_id => 'redmine' }
      )
    assert_routing(
        { :method => 'post',
          :path => "/projects/redmine/repositories" },
        { :controller => 'repositories', :action => 'create', :project_id => 'redmine' }
      )
    assert_routing(
        { :method => 'get',
          :path => "/repositories/1/edit" },
        { :controller => 'repositories', :action => 'edit', :id => '1' }
      )
    assert_routing(
        { :method => 'put',
          :path => "/repositories/1" },
        { :controller => 'repositories', :action => 'update', :id => '1' }
      )
    assert_routing(
        { :method => 'delete',
          :path => "/repositories/1" },
        { :controller => 'repositories', :action => 'destroy', :id => '1' }
      )
    ["get", "post"].each do |method|
      assert_routing(
          { :method => method,
            :path => "/repositories/1/committers" },
          { :controller => 'repositories', :action => 'committers', :id => '1' }
        )
    end
  end

  def test_repositories
    assert_routing(
        { :method => 'get',
          :path => "/projects/redmine/repository" },
        { :controller => 'repositories', :action => 'show', :id => 'redmine' }
      )
    assert_routing(
        { :method => 'get',
          :path => "/projects/redmine/repository/statistics" },
        { :controller => 'repositories', :action => 'stats', :id => 'redmine' }
     )
  end

  def test_repositories_revisions
    empty_path_param = []
    assert_routing(
        { :method => 'get',
          :path => "/projects/redmine/repository/revisions" },
        { :controller => 'repositories', :action => 'revisions', :id => 'redmine' }
      )
    assert_routing(
        { :method => 'get',
          :path => "/projects/redmine/repository/revisions.atom" },
        { :controller => 'repositories', :action => 'revisions', :id => 'redmine',
          :format => 'atom' }
      )
    assert_routing(
        { :method => 'get',
          :path => "/projects/redmine/repository/revisions/2457" },
        { :controller => 'repositories', :action => 'revision', :id => 'redmine',
          :rev => '2457' }
      )
    assert_routing(
        { :method => 'get',
          :path => "/projects/redmine/repository/revisions/2457/show" },
        { :controller => 'repositories', :action => 'show', :id => 'redmine',
          :path => empty_path_param, :rev => '2457' }
      )
    assert_routing(
        { :method => 'get',
          :path => "/projects/redmine/repository/revisions/2457/show/#{@path_hash[:path]}" },
        { :controller => 'repositories', :action => 'show', :id => 'redmine',
          :path => @path_hash[:param] , :rev => '2457'}
      )
    assert_routing(
        { :method => 'get',
          :path => "/projects/redmine/repository/revisions/2457/changes" },
        { :controller => 'repositories', :action => 'changes', :id => 'redmine',
          :path => empty_path_param, :rev => '2457' }
      )
    assert_routing(
        { :method => 'get',
          :path => "/projects/redmine/repository/revisions/2457/changes/#{@path_hash[:path]}" },
        { :controller => 'repositories', :action => 'changes', :id => 'redmine',
          :path => @path_hash[:param] , :rev => '2457'}
      )
    assert_routing(
        { :method => 'get',
          :path => "/projects/redmine/repository/revisions/2457/diff" },
        { :controller => 'repositories', :action => 'diff', :id => 'redmine',
          :rev => '2457' }
      )
    assert_routing(
        { :method => 'get',
          :path => "/projects/redmine/repository/revisions/2457/diff.diff" },
        { :controller => 'repositories', :action => 'diff', :id => 'redmine',
          :rev => '2457', :format => 'diff' }
      )
    assert_routing(
        { :method => 'get',
          :path => "/projects/redmine/repository/revisions/2/diff/#{@path_hash[:path]}" },
        { :controller => 'repositories', :action => 'diff', :id => 'redmine',
          :path => @path_hash[:param], :rev => '2' }
      )
    assert_routing(
        { :method => 'get',
          :path => "/projects/redmine/repository/revisions/2/entry/#{@path_hash[:path]}" },
        { :controller => 'repositories', :action => 'entry', :id => 'redmine',
          :path => @path_hash[:param], :rev => '2' }
      )
    assert_routing(
        { :method => 'get',
          :path => "/projects/redmine/repository/revisions/2/raw/#{@path_hash[:path]}" },
        { :controller => 'repositories', :action => 'entry', :id => 'redmine',
          :path => @path_hash[:param], :rev => '2', :format => 'raw' }
      )
    assert_routing(
        { :method => 'get',
          :path => "/projects/redmine/repository/revisions/2/annotate/#{@path_hash[:path]}" },
        { :controller => 'repositories', :action => 'annotate', :id => 'redmine',
          :path => @path_hash[:param], :rev => '2' }
      )
  end

  def test_repositories_non_revisions_path
    assert_routing(
        { :method => 'get',
          :path => "/projects/redmine/repository/diff/#{@path_hash[:path]}" },
        { :controller => 'repositories', :action => 'diff', :id => 'redmine',
          :path => @path_hash[:param] }
      )
    assert_routing(
        { :method => 'get',
          :path => "/projects/redmine/repository/browse/#{@path_hash[:path]}" },
        { :controller => 'repositories', :action => 'browse', :id => 'redmine',
          :path => @path_hash[:param] }
      )
    assert_routing(
        { :method => 'get',
          :path => "/projects/redmine/repository/entry/#{@path_hash[:path]}" },
        { :controller => 'repositories', :action => 'entry', :id => 'redmine',
          :path => @path_hash[:param] }
      )
    assert_routing(
        { :method => 'get',
          :path => "/projects/redmine/repository/raw/#{@path_hash[:path]}" },
        { :controller => 'repositories', :action => 'entry', :id => 'redmine',
          :path => @path_hash[:param], :format => 'raw' }
      )
    assert_routing(
        { :method => 'get',
          :path => "/projects/redmine/repository/annotate/#{@path_hash[:path]}" },
        { :controller => 'repositories', :action => 'annotate', :id => 'redmine',
          :path => @path_hash[:param] }
      )
    assert_routing(
        { :method => 'get',
          :path => "/projects/redmine/repository/changes/#{@path_hash[:path]}" },
        { :controller => 'repositories', :action => 'changes', :id => 'redmine',
          :path => @path_hash[:param] }
      )
  end

private

  def repository_path_hash(arr)
    hs = {}
    hs[:path]  = arr.join("/")
    hs[:param] = arr
    hs
  end
end
