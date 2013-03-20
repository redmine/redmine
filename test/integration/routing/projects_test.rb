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

class RoutingProjectsTest < ActionController::IntegrationTest
  def test_projects
    assert_routing(
        { :method => 'get', :path => "/projects" },
        { :controller => 'projects', :action => 'index' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects.atom" },
        { :controller => 'projects', :action => 'index', :format => 'atom' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects.xml" },
        { :controller => 'projects', :action => 'index', :format => 'xml' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/new" },
        { :controller => 'projects', :action => 'new' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/test" },
        { :controller => 'projects', :action => 'show', :id => 'test' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/1.xml" },
        { :controller => 'projects', :action => 'show', :id => '1',
          :format => 'xml' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/4223/settings" },
        { :controller => 'projects', :action => 'settings', :id => '4223' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/4223/settings/members" },
        { :controller => 'projects', :action => 'settings', :id => '4223',
          :tab => 'members' }
      )
    assert_routing(
        { :method => 'post', :path => "/projects" },
        { :controller => 'projects', :action => 'create' }
      )
    assert_routing(
        { :method => 'post', :path => "/projects.xml" },
        { :controller => 'projects', :action => 'create', :format => 'xml' }
      )
    assert_routing(
        { :method => 'post', :path => "/projects/64/archive" },
        { :controller => 'projects', :action => 'archive', :id => '64' }
      )
    assert_routing(
        { :method => 'post', :path => "/projects/64/unarchive" },
        { :controller => 'projects', :action => 'unarchive', :id => '64' }
      )
    assert_routing(
        { :method => 'post', :path => "/projects/64/close" },
        { :controller => 'projects', :action => 'close', :id => '64' }
      )
    assert_routing(
        { :method => 'post', :path => "/projects/64/reopen" },
        { :controller => 'projects', :action => 'reopen', :id => '64' }
      )
    assert_routing(
        { :method => 'put', :path => "/projects/4223" },
        { :controller => 'projects', :action => 'update', :id => '4223' }
      )
    assert_routing(
        { :method => 'put', :path => "/projects/1.xml" },
        { :controller => 'projects', :action => 'update', :id => '1',
          :format => 'xml' }
      )
    assert_routing(
        { :method => 'delete', :path => "/projects/64" },
        { :controller => 'projects', :action => 'destroy', :id => '64' }
      )
    assert_routing(
        { :method => 'delete', :path => "/projects/1.xml" },
        { :controller => 'projects', :action => 'destroy', :id => '1',
          :format => 'xml' }
      )
  end
end
