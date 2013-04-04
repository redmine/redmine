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

class RoutingCustomFieldsTest < ActionController::IntegrationTest
  def test_custom_fields
    assert_routing(
        { :method => 'get', :path => "/custom_fields" },
        { :controller => 'custom_fields', :action => 'index' }
      )
    assert_routing(
        { :method => 'get', :path => "/custom_fields/new" },
        { :controller => 'custom_fields', :action => 'new' }
      )
    assert_routing(
        { :method => 'post', :path => "/custom_fields" },
        { :controller => 'custom_fields', :action => 'create' }
      )
    assert_routing(
        { :method => 'get', :path => "/custom_fields/2/edit" },
        { :controller => 'custom_fields', :action => 'edit', :id => '2' }
      )
    assert_routing(
        { :method => 'put', :path => "/custom_fields/2" },
        { :controller => 'custom_fields', :action => 'update', :id => '2' }
      )
    assert_routing(
        { :method => 'delete', :path => "/custom_fields/2" },
        { :controller => 'custom_fields', :action => 'destroy', :id => '2' }
      )
  end
end
