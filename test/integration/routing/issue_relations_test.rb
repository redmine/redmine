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

class RoutingIssueRelationsTest < ActionController::IntegrationTest
  def test_issue_relations
    assert_routing(
        { :method => 'get', :path => "/issues/1/relations" },
        { :controller => 'issue_relations', :action => 'index',
          :issue_id => '1' }
      )
    assert_routing(
        { :method => 'get', :path => "/issues/1/relations.xml" },
        { :controller => 'issue_relations', :action => 'index',
          :issue_id => '1', :format => 'xml' }
      )
    assert_routing(
        { :method => 'get', :path => "/issues/1/relations.json" },
        { :controller => 'issue_relations', :action => 'index',
          :issue_id => '1', :format => 'json' }
      )
    assert_routing(
        { :method => 'post', :path => "/issues/1/relations" },
        { :controller => 'issue_relations', :action => 'create',
          :issue_id => '1' }
      )
    assert_routing(
        { :method => 'post', :path => "/issues/1/relations.xml" },
        { :controller => 'issue_relations', :action => 'create',
          :issue_id => '1', :format => 'xml' }
      )
    assert_routing(
        { :method => 'post', :path => "/issues/1/relations.json" },
        { :controller => 'issue_relations', :action => 'create',
          :issue_id => '1', :format => 'json' }
      )
    assert_routing(
        { :method => 'get', :path => "/relations/23" },
        { :controller => 'issue_relations', :action => 'show', :id => '23' }
      )
    assert_routing(
        { :method => 'get', :path => "/relations/23.xml" },
        { :controller => 'issue_relations', :action => 'show', :id => '23',
          :format => 'xml' }
      )
    assert_routing(
        { :method => 'get', :path => "/relations/23.json" },
        { :controller => 'issue_relations', :action => 'show', :id => '23',
          :format => 'json' }
      )
    assert_routing(
        { :method => 'delete', :path => "/relations/23" },
        { :controller => 'issue_relations', :action => 'destroy', :id => '23' }
      )
    assert_routing(
        { :method => 'delete', :path => "/relations/23.xml" },
        { :controller => 'issue_relations', :action => 'destroy', :id => '23',
          :format => 'xml' }
      )
    assert_routing(
        { :method => 'delete', :path => "/relations/23.json" },
        { :controller => 'issue_relations', :action => 'destroy', :id => '23',
          :format => 'json' }
      )
  end
end
