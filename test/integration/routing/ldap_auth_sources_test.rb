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

class RoutingLdapAuthSourcesTest < ActionController::IntegrationTest
  def test_ldap_auth_sources
    assert_routing(
        { :method => 'get', :path => "/ldap_auth_sources" },
        { :controller => 'ldap_auth_sources', :action => 'index' }
      )
    assert_routing(
        { :method => 'get', :path => "/ldap_auth_sources/new" },
        { :controller => 'ldap_auth_sources', :action => 'new' }
      )
    assert_routing(
        { :method => 'post', :path => "/ldap_auth_sources/create" },
        { :controller => 'ldap_auth_sources', :action => 'create' }
      )
    assert_routing(
        { :method => 'post', :path => "/ldap_auth_sources/destroy/1234" },
        { :controller => 'ldap_auth_sources', :action => 'destroy',
          :id => '1234' }
      )
    assert_routing(
        { :method => 'get', :path => "/ldap_auth_sources/test_connection/1234" },
        { :controller => 'ldap_auth_sources', :action => 'test_connection',
          :id => '1234' }
      )
    assert_routing(
        { :method => 'get', :path => "/ldap_auth_sources/edit/1234" },
        { :controller => 'ldap_auth_sources', :action => 'edit',
          :id => '1234' }
      )
    assert_routing(
        { :method => 'post', :path => "/ldap_auth_sources/update/1234" },
        { :controller => 'ldap_auth_sources', :action => 'update',
          :id => '1234' }
      )
  end
end
