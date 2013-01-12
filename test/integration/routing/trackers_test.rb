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

class RoutingTrackersTest < ActionController::IntegrationTest
  def test_trackers
    assert_routing(
        { :method => 'get', :path => "/trackers" },
        { :controller => 'trackers', :action => 'index' }
      )
    assert_routing(
        { :method => 'get', :path => "/trackers.xml" },
        { :controller => 'trackers', :action => 'index', :format => 'xml' }
      )
    assert_routing(
        { :method => 'post', :path => "/trackers" },
        { :controller => 'trackers', :action => 'create' }
      )
    assert_routing(
        { :method => 'post', :path => "/trackers.xml" },
        { :controller => 'trackers', :action => 'create', :format => 'xml' }
      )
    assert_routing(
        { :method => 'get', :path => "/trackers/new" },
        { :controller => 'trackers', :action => 'new' }
      )
    assert_routing(
        { :method => 'get', :path => "/trackers/new.xml" },
        { :controller => 'trackers', :action => 'new', :format => 'xml' }
      )
    assert_routing(
        { :method => 'get', :path => "/trackers/1/edit" },
        { :controller => 'trackers', :action => 'edit', :id => '1' }
      )
    assert_routing(
        { :method => 'put', :path => "/trackers/1" },
        { :controller => 'trackers', :action => 'update',
          :id => '1' }
      )
    assert_routing(
        { :method => 'put', :path => "/trackers/1.xml" },
        { :controller => 'trackers', :action => 'update',
          :format => 'xml', :id => '1' }
      )
    assert_routing(
        { :method => 'delete', :path => "/trackers/1" },
        { :controller => 'trackers', :action => 'destroy',
          :id => '1' }
      )
    assert_routing(
        { :method => 'delete', :path => "/trackers/1.xml" },
        { :controller => 'trackers', :action => 'destroy',
          :format => 'xml', :id => '1' }
      )
    assert_routing(
        { :method => 'get', :path => "/trackers/fields" },
        { :controller => 'trackers', :action => 'fields' }
      )
    assert_routing(
        { :method => 'post', :path => "/trackers/fields" },
        { :controller => 'trackers', :action => 'fields' }
      )
  end
end
