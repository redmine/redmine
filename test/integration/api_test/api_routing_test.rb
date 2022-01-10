# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2022  Jean-Philippe Lang
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

class Redmine::ApiTest::ApiRoutingTest < Redmine::ApiTest::Routing

  def test_attachments
    should_route 'GET /attachments/1' => 'attachments#show', :id => '1'
    should_route 'PATCH /attachments/1' => 'attachments#update', :id => '1'
    should_route 'DELETE /attachments/1' => 'attachments#destroy', :id => '1'
    should_route 'POST /uploads' => 'attachments#upload'
  end

  def test_custom_fields
    should_route 'GET /custom_fields' => 'custom_fields#index'
  end

  def test_enumerations
    should_route 'GET /enumerations/issue_priorities' => 'enumerations#index', :type => 'issue_priorities'
  end

  def test_files
    should_route 'GET /projects/foo/files' => 'files#index', :project_id => 'foo'
    should_route 'POST /projects/foo/files' => 'files#create', :project_id => 'foo'
  end

  def test_groups
    should_route 'GET /groups' => 'groups#index'
    should_route 'POST /groups' => 'groups#create'

    should_route 'GET /groups/1' => 'groups#show', :id => '1'
    should_route 'PUT /groups/1' => 'groups#update', :id => '1'
    should_route 'DELETE /groups/1' => 'groups#destroy', :id => '1'
  end

  def test_group_users
    should_route 'POST /groups/567/users' => 'groups#add_users', :id => '567'
    should_route 'DELETE /groups/567/users/12' => 'groups#remove_user', :id => '567', :user_id => '12'
  end

  def test_issue_categories
    should_route 'GET /projects/foo/issue_categories' => 'issue_categories#index', :project_id => 'foo'
    should_route 'POST /projects/foo/issue_categories' => 'issue_categories#create', :project_id => 'foo'

    should_route 'GET /issue_categories/1' => 'issue_categories#show', :id => '1'
    should_route 'PUT /issue_categories/1' => 'issue_categories#update', :id => '1'
    should_route 'DELETE /issue_categories/1' => 'issue_categories#destroy', :id => '1'
  end

  def test_issue_relations
    should_route 'GET /issues/1/relations' => 'issue_relations#index', :issue_id => '1'
    should_route 'POST /issues/1/relations' => 'issue_relations#create', :issue_id => '1'

    should_route 'GET /relations/23' => 'issue_relations#show', :id => '23'
    should_route 'DELETE /relations/23' => 'issue_relations#destroy', :id => '23'
  end

  def test_issue_statuses
    should_route 'GET /issue_statuses' => 'issue_statuses#index'
  end

  def test_issues
    should_route 'GET /issues' => 'issues#index'
    should_route 'POST /issues' => 'issues#create'

    should_route 'GET /issues/64' => 'issues#show', :id => '64'
    should_route 'PUT /issues/64' => 'issues#update', :id => '64'
    should_route 'DELETE /issues/64' => 'issues#destroy', :id => '64'
  end

  def test_issue_watchers
    should_route 'POST /issues/12/watchers' => 'watchers#create', :object_type => 'issue', :object_id => '12'
    should_route 'DELETE /issues/12/watchers/3' => 'watchers#destroy', :object_type => 'issue', :object_id => '12', :user_id => '3'
  end

  def test_memberships
    should_route 'GET /projects/5234/memberships' => 'members#index', :project_id => '5234'
    should_route 'POST /projects/5234/memberships' => 'members#create', :project_id => '5234'

    should_route 'GET /memberships/5234' => 'members#show', :id => '5234'
    should_route 'PUT /memberships/5234' => 'members#update', :id => '5234'
    should_route 'DELETE /memberships/5234' => 'members#destroy', :id => '5234'
  end

  def test_news
    should_route 'GET /news' => 'news#index'
    should_route 'GET /projects/567/news' => 'news#index', :project_id => '567'
  end

  def test_projects
    should_route 'GET /projects' => 'projects#index'
    should_route 'POST /projects' => 'projects#create'

    should_route 'GET /projects/1' => 'projects#show', :id => '1'
    should_route 'PUT /projects/1' => 'projects#update', :id => '1'
    should_route 'DELETE /projects/1' => 'projects#destroy', :id => '1'
  end

  def test_queries
    should_route 'GET /queries' => 'queries#index'
  end

  def test_repositories
    should_route 'POST /projects/1/repository/2/revisions/3/issues' => 'repositories#add_related_issue', :id => '1', :repository_id => '2', :rev => '3'
    should_route 'DELETE /projects/1/repository/2/revisions/3/issues/4' => 'repositories#remove_related_issue', :id => '1', :repository_id => '2', :rev => '3', :issue_id => '4'
  end

  def test_roles
    should_route 'GET /roles' => 'roles#index'
    should_route 'GET /roles/2' => 'roles#show', :id => '2'
  end

  def test_time_entries
    should_route 'GET /time_entries' => 'timelog#index'
    should_route 'POST /time_entries' => 'timelog#create'

    should_route 'GET /time_entries/1' => 'timelog#show', :id => '1'
    should_route 'PUT /time_entries/1' => 'timelog#update', :id => '1'
    should_route 'DELETE /time_entries/1' => 'timelog#destroy', :id => '1'
  end

  def test_trackers
    should_route 'GET /trackers' => 'trackers#index'
  end

  def test_users
    should_route 'GET /users' => 'users#index'
    should_route 'POST /users' => 'users#create'

    should_route 'GET /users/44' => 'users#show', :id => '44'
    should_route 'GET /users/current' => 'users#show', :id => 'current'
    should_route 'PUT /users/44' => 'users#update', :id => '44'
    should_route 'DELETE /users/44' => 'users#destroy', :id => '44'
  end

  def test_versions
    should_route 'GET /projects/foo/versions' => 'versions#index', :project_id => 'foo'
    should_route 'POST /projects/foo/versions' => 'versions#create', :project_id => 'foo'

    should_route 'GET /versions/1' => 'versions#show', :id => '1'
    should_route 'PUT /versions/1' => 'versions#update', :id => '1'
    should_route 'DELETE /versions/1' => 'versions#destroy', :id => '1'
  end

  def test_wiki
    should_route 'GET /projects/567/wiki/index' => 'wiki#index', :project_id => '567'

    should_route 'GET /projects/567/wiki/my_page' => 'wiki#show', :project_id => '567', :id => 'my_page'
    should_route 'GET /projects/567/wiki/my_page' => 'wiki#show', :project_id => '567', :id => 'my_page'
    should_route 'GET /projects/1/wiki/my_page/2' => 'wiki#show', :project_id => '1', :id => 'my_page', :version => '2'

    should_route 'PUT /projects/567/wiki/my_page' => 'wiki#update', :project_id => '567', :id => 'my_page'
    should_route 'DELETE /projects/567/wiki/my_page' => 'wiki#destroy', :project_id => '567', :id => 'my_page'
  end
end
