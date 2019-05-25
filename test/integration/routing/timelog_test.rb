# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2019  Jean-Philippe Lang
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

class RoutingTimelogsTest < Redmine::RoutingTest
  def test_timelogs_global
    should_route 'GET /time_entries' => 'timelog#index'
    should_route 'GET /time_entries.csv' => 'timelog#index', :format => 'csv'
    should_route 'GET /time_entries.atom' => 'timelog#index', :format => 'atom'
    should_route 'GET /time_entries/new' => 'timelog#new'
    should_route 'POST /time_entries/new' => 'timelog#new'
    should_route 'POST /time_entries' => 'timelog#create'

    should_route 'GET /time_entries/22/edit' => 'timelog#edit', :id => '22'
    should_route 'PATCH /time_entries/22/edit' => 'timelog#edit', :id => '22'
    should_route 'PATCH /time_entries/22' => 'timelog#update', :id => '22'
    should_route 'DELETE /time_entries/22' => 'timelog#destroy', :id => '22'
  end

  def test_timelogs_scoped_under_project
    should_route 'GET /projects/foo/time_entries' => 'timelog#index', :project_id => 'foo'
    should_route 'GET /projects/foo/time_entries.csv' => 'timelog#index', :project_id => 'foo', :format => 'csv'
    should_route 'GET /projects/foo/time_entries.atom' => 'timelog#index', :project_id => 'foo', :format => 'atom'
    should_route 'GET /projects/foo/time_entries/new' => 'timelog#new', :project_id => 'foo'
    should_route 'POST /projects/foo/time_entries' => 'timelog#create', :project_id => 'foo'
  end

  def test_timelogs_scoped_under_issues
    should_route 'GET  /issues/234/time_entries/new' => 'timelog#new', :issue_id => '234'
    should_route 'POST /issues/234/time_entries' => 'timelog#create', :issue_id => '234'
  end

  def test_timelogs_report
    should_route 'GET /time_entries/report' => 'timelog#report'
    should_route 'GET /time_entries/report.csv' => 'timelog#report', :format => 'csv'

    should_route 'GET /projects/foo/time_entries/report' => 'timelog#report', :project_id => 'foo'
    should_route 'GET /projects/foo/time_entries/report.csv' => 'timelog#report', :project_id => 'foo', :format => 'csv'
  end

  def test_timelogs_bulk_edit
    should_route 'GET /time_entries/bulk_edit' => 'timelog#bulk_edit'
    should_route 'POST /time_entries/bulk_edit' => 'timelog#bulk_edit'
    should_route 'POST /time_entries/bulk_update' => 'timelog#bulk_update'
    should_route 'DELETE /time_entries/destroy' => 'timelog#destroy'
  end
end
