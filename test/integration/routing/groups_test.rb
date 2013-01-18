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

class RoutingGroupsTest < ActionController::IntegrationTest
  def test_groups_resources
    assert_routing(
        { :method => 'get', :path => "/groups" },
        { :controller => 'groups', :action => 'index' }
      )
    assert_routing(
        { :method => 'get', :path => "/groups.xml" },
        { :controller => 'groups', :action => 'index', :format => 'xml' }
      )
    assert_routing(
        { :method => 'post', :path => "/groups" },
        { :controller => 'groups', :action => 'create' }
      )
    assert_routing(
        { :method => 'post', :path => "/groups.xml" },
        { :controller => 'groups', :action => 'create', :format => 'xml' }
      )
    assert_routing(
        { :method => 'get', :path => "/groups/new" },
        { :controller => 'groups', :action => 'new' }
      )
    assert_routing(
        { :method => 'get', :path => "/groups/1/edit" },
        { :controller => 'groups', :action => 'edit', :id => '1' }
      )
    assert_routing(
        { :method => 'get', :path => "/groups/1/autocomplete_for_user" },
        { :controller => 'groups', :action => 'autocomplete_for_user', :id => '1' }
      )
    assert_routing(
        { :method => 'get', :path => "/groups/1/autocomplete_for_user.js" },
        { :controller => 'groups', :action => 'autocomplete_for_user', :id => '1', :format => 'js' }
      )
    assert_routing(
        { :method => 'get', :path => "/groups/1" },
        { :controller => 'groups', :action => 'show', :id => '1' }
      )
    assert_routing(
        { :method => 'get', :path => "/groups/1.xml" },
        { :controller => 'groups', :action => 'show', :id => '1', :format => 'xml' }
      )
    assert_routing(
        { :method => 'put', :path => "/groups/1" },
        { :controller => 'groups', :action => 'update', :id => '1' }
      )
    assert_routing(
        { :method => 'put', :path => "/groups/1.xml" },
        { :controller => 'groups', :action => 'update', :id => '1', :format => 'xml' }
      )
    assert_routing(
        { :method => 'delete', :path => "/groups/1" },
        { :controller => 'groups', :action => 'destroy', :id => '1' }
      )
    assert_routing(
        { :method => 'delete', :path => "/groups/1.xml" },
        { :controller => 'groups', :action => 'destroy', :id => '1', :format => 'xml' }
      )
  end

  def test_groups
    assert_routing(
        { :method => 'post', :path => "/groups/567/users" },
        { :controller => 'groups', :action => 'add_users', :id => '567' }
      )
    assert_routing(
        { :method => 'post', :path => "/groups/567/users.xml" },
        { :controller => 'groups', :action => 'add_users', :id => '567', :format => 'xml' }
      )
    assert_routing(
        { :method => 'delete', :path => "/groups/567/users/12" },
        { :controller => 'groups', :action => 'remove_user', :id => '567', :user_id => '12' }
      )
    assert_routing(
        { :method => 'delete', :path => "/groups/567/users/12.xml" },
        { :controller => 'groups', :action => 'remove_user', :id => '567', :user_id => '12', :format => 'xml' }
      )
    assert_routing(
        { :method => 'post', :path => "/groups/destroy_membership/567" },
        { :controller => 'groups', :action => 'destroy_membership', :id => '567' }
      )
    assert_routing(
        { :method => 'post', :path => "/groups/edit_membership/567" },
        { :controller => 'groups', :action => 'edit_membership', :id => '567' }
      )
  end
end
