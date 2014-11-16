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

require File.expand_path('../../../test_helper', __FILE__)

class RoutingPrincipalMembershipsTest < ActionDispatch::IntegrationTest
  def test_user_memberships
    assert_routing(
        { :method => 'get', :path => "/users/123/memberships/new" },
        { :controller => 'principal_memberships', :action => 'new',
          :user_id => '123' }
      )
    assert_routing(
        { :method => 'post', :path => "/users/123/memberships" },
        { :controller => 'principal_memberships', :action => 'create',
          :user_id => '123' }
      )
    assert_routing(
        { :method => 'put', :path => "/users/123/memberships/55" },
        { :controller => 'principal_memberships', :action => 'update',
          :user_id => '123', :id => '55' }
      )
    assert_routing(
        { :method => 'delete', :path => "/users/123/memberships/55" },
        { :controller => 'principal_memberships', :action => 'destroy',
          :user_id => '123', :id => '55' }
      )
  end

  def test_group_memberships
    assert_routing(
        { :method => 'get', :path => "/groups/123/memberships/new" },
        { :controller => 'principal_memberships', :action => 'new',
          :group_id => '123' }
      )
    assert_routing(
        { :method => 'post', :path => "/groups/123/memberships" },
        { :controller => 'principal_memberships', :action => 'create',
          :group_id => '123' }
      )
    assert_routing(
        { :method => 'put', :path => "/groups/123/memberships/55" },
        { :controller => 'principal_memberships', :action => 'update',
          :group_id => '123', :id => '55' }
      )
    assert_routing(
        { :method => 'delete', :path => "/groups/123/memberships/55" },
        { :controller => 'principal_memberships', :action => 'destroy',
          :group_id => '123', :id => '55' }
      )
  end
end
