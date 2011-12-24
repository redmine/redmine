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
  def test_repositories
    assert_routing(
        { :method => 'get',
          :path => "/projects/redmine/repository" },
        { :controller => 'repositories', :action => 'show', :id => 'redmine' }
      )
    assert_routing(
        { :method => 'get',
          :path => "/projects/redmine/repository/edit" },
        { :controller => 'repositories', :action => 'edit', :id => 'redmine' }
      )
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
          :path => "/projects/redmine/repository/diff/path/to/file.c" },
        { :controller => 'repositories', :action => 'diff', :id => 'redmine',
          :path => %w[path to file.c] }
      )
    assert_routing(
        { :method => 'get',
          :path => "/projects/redmine/repository/revisions/2/diff/path/to/file.c" },
        { :controller => 'repositories', :action => 'diff', :id => 'redmine',
          :path => %w[path to file.c], :rev => '2' }
      )
    assert_routing(
        { :method => 'get',
          :path => "/projects/redmine/repository/browse/path/to/file.c" },
        { :controller => 'repositories', :action => 'browse', :id => 'redmine',
          :path => %w[path to file.c] }
      )
    assert_routing(
        { :method => 'get',
          :path => "/projects/redmine/repository/entry/path/to/file.c" },
        { :controller => 'repositories', :action => 'entry', :id => 'redmine',
          :path => %w[path to file.c] }
      )
    assert_routing(
        { :method => 'get',
          :path => "/projects/redmine/repository/revisions/2/entry/path/to/file.c" },
        { :controller => 'repositories', :action => 'entry', :id => 'redmine',
          :path => %w[path to file.c], :rev => '2' }
      )
    assert_routing(
        { :method => 'get',
          :path => "/projects/redmine/repository/raw/path/to/file.c" },
        { :controller => 'repositories', :action => 'entry', :id => 'redmine',
          :path => %w[path to file.c], :format => 'raw' }
      )
    assert_routing(
        { :method => 'get',
          :path => "/projects/redmine/repository/revisions/2/raw/path/to/file.c" },
        { :controller => 'repositories', :action => 'entry', :id => 'redmine',
          :path => %w[path to file.c], :rev => '2', :format => 'raw' }
      )
    assert_routing(
        { :method => 'get',
          :path => "/projects/redmine/repository/annotate/path/to/file.c" },
        { :controller => 'repositories', :action => 'annotate', :id => 'redmine',
          :path => %w[path to file.c] }
      )
    assert_routing(
        { :method => 'get',
          :path => "/projects/redmine/repository/changes/path/to/file.c" },
        { :controller => 'repositories', :action => 'changes', :id => 'redmine',
          :path => %w[path to file.c] }
      )
    assert_routing(
        { :method => 'get',
          :path => "/projects/redmine/repository/statistics" },
        { :controller => 'repositories', :action => 'stats', :id => 'redmine' }
      )
    assert_routing(
        { :method => 'post',
          :path => "/projects/redmine/repository/edit" },
        { :controller => 'repositories', :action => 'edit', :id => 'redmine' }
      )
  end
end
