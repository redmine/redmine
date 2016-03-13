# Redmine - project management software
# Copyright (C) 2006-2016  Jean-Philippe Lang
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

class RoutingIssuesTest < Redmine::RoutingTest
  def test_issues
    should_route 'GET /issues' => 'issues#index'
    should_route 'GET /issues.pdf' => 'issues#index', :format => 'pdf'
    should_route 'GET /issues.atom' => 'issues#index', :format => 'atom'

    should_route 'GET /issues/64' => 'issues#show', :id => '64'
    should_route 'GET /issues/64.pdf' => 'issues#show', :id => '64', :format => 'pdf'
    should_route 'GET /issues/64.atom' => 'issues#show', :id => '64', :format => 'atom'

    should_route 'GET /issues/new' => 'issues#new'
    should_route 'POST /issues' => 'issues#create'

    should_route 'GET /issues/64/edit' => 'issues#edit', :id => '64'
    should_route 'PUT /issues/64' => 'issues#update', :id => '64'
    should_route 'DELETE /issues/64' => 'issues#destroy', :id => '64'
  end

  def test_issues_bulk_edit
    should_route 'GET /issues/bulk_edit' => 'issues#bulk_edit'
    should_route 'POST /issues/bulk_edit' => 'issues#bulk_edit' # For updating the bulk edit form
    should_route 'POST /issues/bulk_update' => 'issues#bulk_update'
  end

  def test_issues_scoped_under_project
    should_route 'GET /projects/23/issues' => 'issues#index', :project_id => '23'
    should_route 'GET /projects/23/issues.pdf' => 'issues#index', :project_id => '23', :format => 'pdf'
    should_route 'GET /projects/23/issues.atom' => 'issues#index', :project_id => '23', :format => 'atom'

    should_route 'GET /projects/23/issues/new' => 'issues#new', :project_id => '23'
    should_route 'POST /projects/23/issues' => 'issues#create', :project_id => '23'

    should_route 'GET /projects/23/issues/64/copy' => 'issues#new', :project_id => '23', :copy_from => '64'
  end

  def test_issues_form_update
    should_route 'POST /issues/new' => 'issues#new'
    should_route 'POST /projects/23/issues/new' => 'issues#new', :project_id => '23'
    should_route 'PATCH /issues/23/edit' => 'issues#edit', :id => '23'
  end
end
