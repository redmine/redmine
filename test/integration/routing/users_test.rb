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

class RoutingUsersTest < ActionController::IntegrationTest
  def test_users
    assert_routing(
        { :method => 'get', :path => "/users" },
        { :controller => 'users', :action => 'index' }
      )
    assert_routing(
        { :method => 'get', :path => "/users.xml" },
        { :controller => 'users', :action => 'index', :format => 'xml' }
      )
    assert_routing(
        { :method => 'get', :path => "/users/44" },
        { :controller => 'users', :action => 'show', :id => '44' }
      )
    assert_routing(
        { :method => 'get', :path => "/users/44.xml" },
        { :controller => 'users', :action => 'show', :id => '44',
          :format => 'xml' }
      )
    assert_routing(
        { :method => 'get', :path => "/users/current" },
        { :controller => 'users', :action => 'show', :id => 'current' }
      )
    assert_routing(
        { :method => 'get', :path => "/users/current.xml" },
        { :controller => 'users', :action => 'show', :id => 'current',
          :format => 'xml' }
      )
    assert_routing(
        { :method => 'get', :path => "/users/new" },
        { :controller => 'users', :action => 'new' }
      )
    assert_routing(
        { :method => 'get', :path => "/users/444/edit" },
        { :controller => 'users', :action => 'edit', :id => '444' }
      )
    assert_routing(
        { :method => 'post', :path => "/users" },
        { :controller => 'users', :action => 'create' }
      )
    assert_routing(
        { :method => 'post', :path => "/users.xml" },
        { :controller => 'users', :action => 'create', :format => 'xml' }
      )
    assert_routing(
        { :method => 'put', :path => "/users/444" },
        { :controller => 'users', :action => 'update', :id => '444' }
      )
    assert_routing(
        { :method => 'put', :path => "/users/444.xml" },
        { :controller => 'users', :action => 'update', :id => '444',
          :format => 'xml' }
      )
    assert_routing(
        { :method => 'delete', :path => "/users/44" },
        { :controller => 'users', :action => 'destroy', :id => '44' }
      )
    assert_routing(
        { :method => 'delete', :path => "/users/44.xml" },
        { :controller => 'users', :action => 'destroy', :id => '44',
          :format => 'xml' }
      )
    assert_routing(
        { :method => 'post', :path => "/users/123/memberships" },
        { :controller => 'users', :action => 'edit_membership',
          :id => '123' }
      )
    assert_routing(
        { :method => 'put', :path => "/users/123/memberships/55" },
        { :controller => 'users', :action => 'edit_membership',
          :id => '123', :membership_id => '55' }
      )
    assert_routing(
        { :method => 'delete', :path => "/users/123/memberships/55" },
        { :controller => 'users', :action => 'destroy_membership',
          :id => '123', :membership_id => '55' }
      )
  end
end
