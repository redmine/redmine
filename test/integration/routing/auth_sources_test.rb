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

class RoutingAuthSourcesTest < ActionController::IntegrationTest
  def test_auth_sources
    assert_routing(
        { :method => 'get', :path => "/auth_sources" },
        { :controller => 'auth_sources', :action => 'index' }
      )
    assert_routing(
        { :method => 'get', :path => "/auth_sources/new" },
        { :controller => 'auth_sources', :action => 'new' }
      )
    assert_routing(
        { :method => 'post', :path => "/auth_sources" },
        { :controller => 'auth_sources', :action => 'create' }
      )
    assert_routing(
        { :method => 'get', :path => "/auth_sources/1234/edit" },
        { :controller => 'auth_sources', :action => 'edit',
          :id => '1234' }
      )
    assert_routing(
        { :method => 'put', :path => "/auth_sources/1234" },
        { :controller => 'auth_sources', :action => 'update',
          :id => '1234' }
      )
    assert_routing(
        { :method => 'delete', :path => "/auth_sources/1234" },
        { :controller => 'auth_sources', :action => 'destroy',
          :id => '1234' }
      )
    assert_routing(
        { :method => 'get', :path => "/auth_sources/1234/test_connection" },
        { :controller => 'auth_sources', :action => 'test_connection',
          :id => '1234' }
      )
    assert_routing(
        { :method => 'get', :path => "/auth_sources/autocomplete_for_new_user" },
        { :controller => 'auth_sources', :action => 'autocomplete_for_new_user' }
      )
  end
end
