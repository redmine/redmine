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

class RoutingMyTest < ActionController::IntegrationTest
  def test_my
    ["get", "post"].each do |method|
      assert_routing(
          { :method => method, :path => "/my/account" },
          { :controller => 'my', :action => 'account' }
        )
    end
    ["get", "post"].each do |method|
      assert_routing(
          { :method => method, :path => "/my/account/destroy" },
          { :controller => 'my', :action => 'destroy' }
        )
    end
    assert_routing(
        { :method => 'get', :path => "/my/page" },
        { :controller => 'my', :action => 'page' }
      )
    assert_routing(
        { :method => 'get', :path => "/my" },
        { :controller => 'my', :action => 'index' }
      )
    assert_routing(
        { :method => 'post', :path => "/my/reset_rss_key" },
        { :controller => 'my', :action => 'reset_rss_key' }
      )
    assert_routing(
        { :method => 'post', :path => "/my/reset_api_key" },
        { :controller => 'my', :action => 'reset_api_key' }
      )
    ["get", "post"].each do |method|
      assert_routing(
          { :method => method, :path => "/my/password" },
          { :controller => 'my', :action => 'password' }
        )
    end
    assert_routing(
        { :method => 'get', :path => "/my/page_layout" },
        { :controller => 'my', :action => 'page_layout' }
      )
    assert_routing(
        { :method => 'post', :path => "/my/add_block" },
        { :controller => 'my', :action => 'add_block' }
      )
    assert_routing(
        { :method => 'post', :path => "/my/remove_block" },
        { :controller => 'my', :action => 'remove_block' }
      )
    assert_routing(
        { :method => 'post', :path => "/my/order_blocks" },
        { :controller => 'my', :action => 'order_blocks' }
      )
  end
end
