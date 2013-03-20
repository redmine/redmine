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

class RoutingIssueStatusesTest < ActionController::IntegrationTest
  def test_issue_statuses
    assert_routing(
        { :method => 'get', :path => "/issue_statuses" },
        { :controller => 'issue_statuses', :action => 'index' }
      )
    assert_routing(
        { :method => 'get', :path => "/issue_statuses.xml" },
        { :controller => 'issue_statuses', :action => 'index', :format => 'xml' }
      )
    assert_routing(
        { :method => 'post', :path => "/issue_statuses" },
        { :controller => 'issue_statuses', :action => 'create' }
      )
    assert_routing(
        { :method => 'post', :path => "/issue_statuses.xml" },
        { :controller => 'issue_statuses', :action => 'create', :format => 'xml' }
      )
    assert_routing(
        { :method => 'get', :path => "/issue_statuses/new" },
        { :controller => 'issue_statuses', :action => 'new' }
      )
    assert_routing(
        { :method => 'get', :path => "/issue_statuses/new.xml" },
        { :controller => 'issue_statuses', :action => 'new', :format => 'xml' }
      )
    assert_routing(
        { :method => 'get', :path => "/issue_statuses/1/edit" },
        { :controller => 'issue_statuses', :action => 'edit', :id => '1' }
      )
    assert_routing(
        { :method => 'put', :path => "/issue_statuses/1" },
        { :controller => 'issue_statuses', :action => 'update',
          :id => '1' }
      )
    assert_routing(
        { :method => 'put', :path => "/issue_statuses/1.xml" },
        { :controller => 'issue_statuses', :action => 'update',
          :format => 'xml', :id => '1' }
      )
    assert_routing(
        { :method => 'delete', :path => "/issue_statuses/1" },
        { :controller => 'issue_statuses', :action => 'destroy',
          :id => '1' }
      )
    assert_routing(
        { :method => 'delete', :path => "/issue_statuses/1.xml" },
        { :controller => 'issue_statuses', :action => 'destroy',
          :format => 'xml', :id => '1' }
      )
    assert_routing(
        { :method => 'post', :path => "/issue_statuses/update_issue_done_ratio" },
        { :controller => 'issue_statuses', :action => 'update_issue_done_ratio' }
      )
    assert_routing(
        { :method => 'post', :path => "/issue_statuses/update_issue_done_ratio.xml" },
        { :controller => 'issue_statuses', :action => 'update_issue_done_ratio',
          :format => 'xml' }
      )
  end
end
