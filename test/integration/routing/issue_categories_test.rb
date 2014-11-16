# Redmine - project management software
# Copyright (C) 2006-2014  Jean-Philippe Lang
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

class RoutingIssueCategoriesTest < ActionDispatch::IntegrationTest
  def test_issue_categories_scoped_under_project
    assert_routing(
        { :method => 'get', :path => "/projects/foo/issue_categories" },
        { :controller => 'issue_categories', :action => 'index',
          :project_id => 'foo' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/foo/issue_categories/new" },
        { :controller => 'issue_categories', :action => 'new',
          :project_id => 'foo' }
      )
    assert_routing(
        { :method => 'post', :path => "/projects/foo/issue_categories" },
        { :controller => 'issue_categories', :action => 'create',
          :project_id => 'foo' }
      )
  end

  def test_issue_categories
    assert_routing(
        { :method => 'get', :path => "/issue_categories/1" },
        { :controller => 'issue_categories', :action => 'show', :id => '1' }
      )
    assert_routing(
        { :method => 'get', :path => "/issue_categories/1/edit" },
        { :controller => 'issue_categories', :action => 'edit', :id => '1' }
      )
    assert_routing(
        { :method => 'put', :path => "/issue_categories/1" },
        { :controller => 'issue_categories', :action => 'update', :id => '1' }
      )
    assert_routing(
        { :method => 'delete', :path => "/issue_categories/1" },
        { :controller => 'issue_categories', :action => 'destroy', :id => '1' }
      )
  end
end
