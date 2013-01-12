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

class RoutingEnumerationsTest < ActionController::IntegrationTest
  def test_enumerations
    assert_routing(
        { :method => 'get', :path => "/enumerations" },
        { :controller => 'enumerations', :action => 'index' }
      )
    assert_routing(
        { :method => 'get', :path => "/enumerations/new" },
        { :controller => 'enumerations', :action => 'new' }
      )
    assert_routing(
        { :method => 'post', :path => "/enumerations" },
        { :controller => 'enumerations', :action => 'create' }
      )
    assert_routing(
        { :method => 'get', :path => "/enumerations/2/edit" },
        { :controller => 'enumerations', :action => 'edit', :id => '2' }
      )
    assert_routing(
        { :method => 'put', :path => "/enumerations/2" },
        { :controller => 'enumerations', :action => 'update', :id => '2' }
      )
    assert_routing(
        { :method => 'delete', :path => "/enumerations/2" },
        { :controller => 'enumerations', :action => 'destroy', :id => '2' }
      )
    assert_routing(
        { :method => 'get', :path => "/enumerations/issue_priorities.xml" },
        { :controller => 'enumerations', :action => 'index', :type => 'issue_priorities', :format => 'xml' }
      )
  end
end
