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

class RoutingMembersTest < ActionController::IntegrationTest
  def test_members
    assert_routing(
        { :method => 'get', :path => "/projects/5234/memberships.xml" },
        { :controller => 'members', :action => 'index', :project_id => '5234', :format => 'xml' }
      )
    assert_routing(
        { :method => 'get', :path => "/memberships/5234.xml" },
        { :controller => 'members', :action => 'show', :id => '5234', :format => 'xml' }
      )
    assert_routing(
        { :method => 'post', :path => "/projects/5234/memberships" },
        { :controller => 'members', :action => 'create', :project_id => '5234' }
      )
    assert_routing(
        { :method => 'post', :path => "/projects/5234/memberships.xml" },
        { :controller => 'members', :action => 'create', :project_id => '5234', :format => 'xml' }
      )
    assert_routing(
        { :method => 'put', :path => "/memberships/5234" },
        { :controller => 'members', :action => 'update', :id => '5234' }
      )
    assert_routing(
        { :method => 'put', :path => "/memberships/5234.xml" },
        { :controller => 'members', :action => 'update', :id => '5234', :format => 'xml' }
      )
    assert_routing(
        { :method => 'delete', :path => "/memberships/5234" },
        { :controller => 'members', :action => 'destroy', :id => '5234' }
      )
    assert_routing(
        { :method => 'delete', :path => "/memberships/5234.xml" },
        { :controller => 'members', :action => 'destroy', :id => '5234', :format => 'xml' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/5234/memberships/autocomplete" },
        { :controller => 'members', :action => 'autocomplete', :project_id => '5234' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/5234/memberships/autocomplete.js" },
        { :controller => 'members', :action => 'autocomplete', :project_id => '5234', :format => 'js' }
      )
  end
end
