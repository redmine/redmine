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

class RoutingTimelogsTest < ActionController::IntegrationTest
  def test_timelogs_global
    assert_routing(
        { :method => 'get', :path => "/time_entries" },
        { :controller => 'timelog', :action => 'index' }
      )
    assert_routing(
        { :method => 'get', :path => "/time_entries.csv" },
        { :controller => 'timelog', :action => 'index', :format => 'csv' }
      )
    assert_routing(
        { :method => 'get', :path => "/time_entries.atom" },
        { :controller => 'timelog', :action => 'index', :format => 'atom' }
      )
    assert_routing(
        { :method => 'get', :path => "/time_entries/new" },
        { :controller => 'timelog', :action => 'new' }
      )
    assert_routing(
        { :method => 'get', :path => "/time_entries/22/edit" },
        { :controller => 'timelog', :action => 'edit', :id => '22' }
      )
    assert_routing(
        { :method => 'post', :path => "/time_entries" },
        { :controller => 'timelog', :action => 'create' }
      )
    assert_routing(
        { :method => 'put', :path => "/time_entries/22" },
        { :controller => 'timelog', :action => 'update', :id => '22' }
      )
    assert_routing(
        { :method => 'delete', :path => "/time_entries/55" },
        { :controller => 'timelog', :action => 'destroy', :id => '55' }
      )
  end

  def test_timelogs_scoped_under_project
    assert_routing(
        { :method => 'get', :path => "/projects/567/time_entries" },
        { :controller => 'timelog', :action => 'index', :project_id => '567' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/567/time_entries.csv" },
        { :controller => 'timelog', :action => 'index', :project_id => '567',
          :format => 'csv' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/567/time_entries.atom" },
        { :controller => 'timelog', :action => 'index', :project_id => '567',
          :format => 'atom' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/567/time_entries/new" },
        { :controller => 'timelog', :action => 'new', :project_id => '567' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/567/time_entries/22/edit" },
        { :controller => 'timelog', :action => 'edit',
          :id => '22', :project_id => '567' }
      )
    assert_routing(
        { :method => 'post', :path => "/projects/567/time_entries" },
        { :controller => 'timelog', :action => 'create',
          :project_id => '567' }
      )
    assert_routing(
        { :method => 'put', :path => "/projects/567/time_entries/22" },
        { :controller => 'timelog', :action => 'update',
          :id => '22', :project_id => '567' }
      )
    assert_routing(
        { :method => 'delete', :path => "/projects/567/time_entries/55" },
        { :controller => 'timelog', :action => 'destroy',
          :id => '55', :project_id => '567' }
      )
  end

  def test_timelogs_scoped_under_issues
    assert_routing(
        { :method => 'get', :path => "/issues/234/time_entries" },
        { :controller => 'timelog', :action => 'index', :issue_id => '234' }
      )
    assert_routing(
        { :method => 'get', :path => "/issues/234/time_entries.csv" },
        { :controller => 'timelog', :action => 'index', :issue_id => '234',
          :format => 'csv' }
      )
    assert_routing(
        { :method => 'get', :path => "/issues/234/time_entries.atom" },
        { :controller => 'timelog', :action => 'index', :issue_id => '234',
          :format => 'atom' }
      )
    assert_routing(
        { :method => 'get', :path => "/issues/234/time_entries/new" },
        { :controller => 'timelog', :action => 'new', :issue_id => '234' }
      )
    assert_routing(
        { :method => 'get', :path => "/issues/234/time_entries/22/edit" },
        { :controller => 'timelog', :action => 'edit', :id => '22',
          :issue_id => '234' }
      )
    assert_routing(
        { :method => 'post', :path => "/issues/234/time_entries" },
        { :controller => 'timelog', :action => 'create', :issue_id => '234' }
      )
    assert_routing(
        { :method => 'put', :path => "/issues/234/time_entries/22" },
        { :controller => 'timelog', :action => 'update', :id => '22',
          :issue_id => '234' }
      )
    assert_routing(
        { :method => 'delete', :path => "/issues/234/time_entries/55" },
        { :controller => 'timelog', :action => 'destroy', :id => '55',
          :issue_id => '234' }
      )
  end

  def test_timelogs_scoped_under_project_and_issues
    assert_routing(
        { :method => 'get',
          :path => "/projects/ecookbook/issues/234/time_entries" },
        { :controller => 'timelog', :action => 'index',
          :issue_id => '234', :project_id => 'ecookbook' }
      )
    assert_routing(
        { :method => 'get',
          :path => "/projects/ecookbook/issues/234/time_entries.csv" },
        { :controller => 'timelog', :action => 'index',
          :issue_id => '234', :project_id => 'ecookbook', :format => 'csv' }
      )
    assert_routing(
        { :method => 'get',
          :path => "/projects/ecookbook/issues/234/time_entries.atom" },
        { :controller => 'timelog', :action => 'index',
          :issue_id => '234', :project_id => 'ecookbook', :format => 'atom' }
      )
    assert_routing(
        { :method => 'get',
          :path => "/projects/ecookbook/issues/234/time_entries/new" },
        { :controller => 'timelog', :action => 'new',
          :issue_id => '234', :project_id => 'ecookbook' }
      )
    assert_routing(
        { :method => 'get',
          :path => "/projects/ecookbook/issues/234/time_entries/22/edit" },
        { :controller => 'timelog', :action => 'edit', :id => '22',
          :issue_id => '234', :project_id => 'ecookbook' }
      )
    assert_routing(
        { :method => 'post',
          :path => "/projects/ecookbook/issues/234/time_entries" },
        { :controller => 'timelog', :action => 'create',
          :issue_id => '234', :project_id => 'ecookbook' }
      )
    assert_routing(
        { :method => 'put',
          :path => "/projects/ecookbook/issues/234/time_entries/22" },
        { :controller => 'timelog', :action => 'update', :id => '22',
          :issue_id => '234', :project_id => 'ecookbook' }
      )
    assert_routing(
        { :method => 'delete',
          :path => "/projects/ecookbook/issues/234/time_entries/55" },
        { :controller => 'timelog', :action => 'destroy', :id => '55',
          :issue_id => '234', :project_id => 'ecookbook' }
      )
  end

  def test_timelogs_report
    assert_routing(
        { :method => 'get',
          :path => "/time_entries/report" },
        { :controller => 'timelog', :action => 'report' }
      )
    assert_routing(
        { :method => 'get',
          :path => "/time_entries/report.csv" },
        { :controller => 'timelog', :action => 'report', :format => 'csv' }
      )
    assert_routing(
        { :method => 'get',
          :path => "/issues/234/time_entries/report" },
        { :controller => 'timelog', :action => 'report', :issue_id => '234' }
      )
    assert_routing(
        { :method => 'get',
          :path => "/issues/234/time_entries/report.csv" },
        { :controller => 'timelog', :action => 'report', :issue_id => '234',
          :format => 'csv' }
      )
    assert_routing(
        { :method => 'get',
          :path => "/projects/567/time_entries/report" },
        { :controller => 'timelog', :action => 'report', :project_id => '567' }
      )
    assert_routing(
        { :method => 'get',
          :path => "/projects/567/time_entries/report.csv" },
        { :controller => 'timelog', :action => 'report', :project_id => '567',
          :format => 'csv' }
      )
  end

  def test_timelogs_bulk_edit
    assert_routing(
        { :method => 'delete',
          :path => "/time_entries/destroy" },
        { :controller => 'timelog', :action => 'destroy' }
      )
    assert_routing(
        { :method => 'post',
          :path => "/time_entries/bulk_update" },
        { :controller => 'timelog', :action => 'bulk_update' }
      )
    assert_routing(
        { :method => 'get',
          :path => "/time_entries/bulk_edit" },
        { :controller => 'timelog', :action => 'bulk_edit' }
      )
  end
end
