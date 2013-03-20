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

class RoutingIssuesTest < ActionController::IntegrationTest
  def test_issues_rest_actions
    assert_routing(
        { :method => 'get', :path => "/issues" },
        { :controller => 'issues', :action => 'index' }
      )
    assert_routing(
        { :method => 'get', :path => "/issues.pdf" },
        { :controller => 'issues', :action => 'index', :format => 'pdf' }
      )
    assert_routing(
        { :method => 'get', :path => "/issues.atom" },
        { :controller => 'issues', :action => 'index', :format => 'atom' }
      )
    assert_routing(
        { :method => 'get', :path => "/issues.xml" },
        { :controller => 'issues', :action => 'index', :format => 'xml' }
      )
    assert_routing(
        { :method => 'get', :path => "/issues/64" },
        { :controller => 'issues', :action => 'show', :id => '64' }
      )
    assert_routing(
        { :method => 'get', :path => "/issues/64.pdf" },
        { :controller => 'issues', :action => 'show', :id => '64',
          :format => 'pdf' }
      )
    assert_routing(
        { :method => 'get', :path => "/issues/64.atom" },
        { :controller => 'issues', :action => 'show', :id => '64',
          :format => 'atom' }
      )
    assert_routing(
        { :method => 'get', :path => "/issues/64.xml" },
        { :controller => 'issues', :action => 'show', :id => '64',
          :format => 'xml' }
      )
    assert_routing(
        { :method => 'post', :path => "/issues.xml" },
        { :controller => 'issues', :action => 'create', :format => 'xml' }
      )
    assert_routing(
        { :method => 'get', :path => "/issues/64/edit" },
        { :controller => 'issues', :action => 'edit', :id => '64' }
      )
    assert_routing(
        { :method => 'put', :path => "/issues/1.xml" },
        { :controller => 'issues', :action => 'update', :id => '1',
          :format => 'xml' }
      )
    assert_routing(
        { :method => 'delete', :path => "/issues/1.xml" },
        { :controller => 'issues', :action => 'destroy', :id => '1',
          :format => 'xml' }
      )
  end

  def test_issues_rest_actions_scoped_under_project
    assert_routing(
        { :method => 'get', :path => "/projects/23/issues" },
        { :controller => 'issues', :action => 'index', :project_id => '23' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/23/issues.pdf" },
        { :controller => 'issues', :action => 'index', :project_id => '23',
          :format => 'pdf' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/23/issues.atom" },
        { :controller => 'issues', :action => 'index', :project_id => '23',
          :format => 'atom' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/23/issues.xml" },
        { :controller => 'issues', :action => 'index', :project_id => '23',
          :format => 'xml' }
      )
    assert_routing(
        { :method => 'post', :path => "/projects/23/issues" },
        { :controller => 'issues', :action => 'create', :project_id => '23' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/23/issues/new" },
        { :controller => 'issues', :action => 'new', :project_id => '23' }
      )
  end

  def test_issues_form_update
    ["post", "put"].each do |method|
      assert_routing(
          { :method => method, :path => "/projects/23/issues/update_form" },
          { :controller => 'issues', :action => 'update_form', :project_id => '23' }
        )
    end
  end

  def test_issues_extra_actions
    assert_routing(
        { :method => 'get', :path => "/projects/23/issues/64/copy" },
        { :controller => 'issues', :action => 'new', :project_id => '23',
          :copy_from => '64' }
      )
    # For updating the bulk edit form
    ["get", "post"].each do |method|
      assert_routing(
          { :method => method, :path => "/issues/bulk_edit" },
          { :controller => 'issues', :action => 'bulk_edit' }
        )
    end
    assert_routing(
        { :method => 'post', :path => "/issues/bulk_update" },
        { :controller => 'issues', :action => 'bulk_update' }
      )
  end
end
