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

class RoutingWatchersTest < ActionController::IntegrationTest
  def test_watchers
    assert_routing(
        { :method => 'get', :path => "/watchers/new" },
        { :controller => 'watchers', :action => 'new' }
      )
    assert_routing(
        { :method => 'post', :path => "/watchers/append" },
        { :controller => 'watchers', :action => 'append' }
      )
    assert_routing(
        { :method => 'post', :path => "/watchers" },
        { :controller => 'watchers', :action => 'create' }
      )
    assert_routing(
        { :method => 'delete', :path => "/watchers" },
        { :controller => 'watchers', :action => 'destroy' }
      )
    assert_routing(
        { :method => 'get', :path => "/watchers/autocomplete_for_user" },
        { :controller => 'watchers', :action => 'autocomplete_for_user' }
      )
    assert_routing(
        { :method => 'post', :path => "/watchers/watch" },
        { :controller => 'watchers', :action => 'watch' }
      )
    assert_routing(
        { :method => 'delete', :path => "/watchers/watch" },
        { :controller => 'watchers', :action => 'unwatch' }
      )
    assert_routing(
        { :method => 'post', :path => "/issues/12/watchers.xml" },
        { :controller => 'watchers', :action => 'create',
          :object_type => 'issue', :object_id => '12', :format => 'xml' }
      )
    assert_routing(
        { :method => 'delete', :path => "/issues/12/watchers/3.xml" },
        { :controller => 'watchers', :action => 'destroy',
          :object_type => 'issue', :object_id => '12', :user_id => '3', :format => 'xml'}
      )
  end
end
