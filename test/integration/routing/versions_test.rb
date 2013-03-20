# Redmine - project management software
# Copyright (C) 2006-2013  Jean-Philippe Lang
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

class RoutingVersionsTest < ActionController::IntegrationTest
  def test_roadmap
    # /projects/foo/versions is /projects/foo/roadmap
    assert_routing(
        { :method => 'get', :path => "/projects/33/roadmap" },
        { :controller => 'versions', :action => 'index', :project_id => '33' }
      )
  end

  def test_versions_scoped_under_project
    assert_routing(
        { :method => 'put', :path => "/projects/foo/versions/close_completed" },
        { :controller => 'versions', :action => 'close_completed',
          :project_id => 'foo' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/foo/versions.xml" },
        { :controller => 'versions', :action => 'index',
          :project_id => 'foo', :format => 'xml' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/foo/versions.json" },
        { :controller => 'versions', :action => 'index',
          :project_id => 'foo', :format => 'json' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/foo/versions/new" },
        { :controller => 'versions', :action => 'new',
          :project_id => 'foo' }
      )
    assert_routing(
        { :method => 'post', :path => "/projects/foo/versions" },
        { :controller => 'versions', :action => 'create',
          :project_id => 'foo' }
      )
    assert_routing(
        { :method => 'post', :path => "/projects/foo/versions.xml" },
        { :controller => 'versions', :action => 'create',
          :project_id => 'foo', :format => 'xml' }
      )
    assert_routing(
        { :method => 'post', :path => "/projects/foo/versions.json" },
        { :controller => 'versions', :action => 'create',
          :project_id => 'foo', :format => 'json' }
      )
  end

  def test_versions
    assert_routing(
        { :method => 'get', :path => "/versions/1" },
        { :controller => 'versions', :action => 'show', :id => '1' }
      )
    assert_routing(
        { :method => 'get', :path => "/versions/1.xml" },
        { :controller => 'versions', :action => 'show', :id => '1',
          :format => 'xml' }
      )
    assert_routing(
        { :method => 'get', :path => "/versions/1.json" },
        { :controller => 'versions', :action => 'show', :id => '1',
          :format => 'json' }
      )
    assert_routing(
        { :method => 'get', :path => "/versions/1/edit" },
        { :controller => 'versions', :action => 'edit', :id => '1' }
      )
    assert_routing(
        { :method => 'put', :path => "/versions/1" },
        { :controller => 'versions', :action => 'update', :id => '1' }
      )
    assert_routing(
        { :method => 'put', :path => "/versions/1.xml" },
        { :controller => 'versions', :action => 'update', :id => '1',
          :format => 'xml' }
      )
    assert_routing(
        { :method => 'put', :path => "/versions/1.json" },
        { :controller => 'versions', :action => 'update', :id => '1',
          :format => 'json' }
      )
    assert_routing(
        { :method => 'delete', :path => "/versions/1" },
        { :controller => 'versions', :action => 'destroy', :id => '1' }
      )
    assert_routing(
        { :method => 'delete', :path => "/versions/1.xml" },
        { :controller => 'versions', :action => 'destroy', :id => '1',
          :format => 'xml' }
      )
    assert_routing(
        { :method => 'delete', :path => "/versions/1.json" },
        { :controller => 'versions', :action => 'destroy', :id => '1',
          :format => 'json' }
      )
    assert_routing(
        { :method => 'post', :path => "/versions/1/status_by" },
        { :controller => 'versions', :action => 'status_by', :id => '1' }
      )
  end
end
