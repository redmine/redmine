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

class RoutingQueriesTest < ActionController::IntegrationTest
  def test_queries
    assert_routing(
        { :method => 'get', :path => "/queries.xml" },
        { :controller => 'queries', :action => 'index', :format => 'xml' }
      )
    assert_routing(
        { :method => 'get', :path => "/queries.json" },
        { :controller => 'queries', :action => 'index', :format => 'json' }
      )
    assert_routing(
        { :method => 'get', :path => "/queries/new" },
        { :controller => 'queries', :action => 'new' }
      )
    assert_routing(
        { :method => 'post', :path => "/queries" },
        { :controller => 'queries', :action => 'create' }
      )
    assert_routing(
        { :method => 'get', :path => "/queries/1/edit" },
        { :controller => 'queries', :action => 'edit', :id => '1' }
      )
    assert_routing(
        { :method => 'put', :path => "/queries/1" },
        { :controller => 'queries', :action => 'update', :id => '1' }
      )
    assert_routing(
        { :method => 'delete', :path => "/queries/1" },
        { :controller => 'queries', :action => 'destroy', :id => '1' }
      )
  end

  def test_queries_scoped_under_project
    assert_routing(
        { :method => 'get', :path => "/projects/redmine/queries/new" },
        { :controller => 'queries', :action => 'new', :project_id => 'redmine' }
      )
    assert_routing(
        { :method => 'post', :path => "/projects/redmine/queries" },
        { :controller => 'queries', :action => 'create', :project_id => 'redmine' }
      )
  end
end
