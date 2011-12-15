# Redmine - project management software
# Copyright (C) 2006-2011  Jean-Philippe Lang
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

require File.expand_path('../../test_helper', __FILE__)

class RoutingTest < ActionController::IntegrationTest
  def test_activities
    assert_routing(
           { :method => 'get', :path => "/activity" },
           { :controller => 'activities', :action => 'index', :id => nil }
        )
    assert_routing(
           { :method => 'get', :path => "/activity.atom" },
           { :controller => 'activities', :action => 'index', :id => nil, :format => 'atom' }
        )
  end

  def test_attachments
    assert_routing(
           { :method => 'get', :path => "/attachments/1" },
           { :controller => 'attachments', :action => 'show', :id => '1' }
         )
    assert_routing(
           { :method => 'get', :path => "/attachments/1.xml" },
           { :controller => 'attachments', :action => 'show', :id => '1', :format => 'xml' }
         )
    assert_routing(
           { :method => 'get', :path => "/attachments/1.json" },
           { :controller => 'attachments', :action => 'show', :id => '1', :format => 'json' }
         )
    assert_routing(
           { :method => 'get', :path => "/attachments/1/filename.ext" },
           { :controller => 'attachments', :action => 'show', :id => '1',
             :filename => 'filename.ext' }
         )
    assert_routing(
           { :method => 'get', :path => "/attachments/download/1" },
           { :controller => 'attachments', :action => 'download', :id => '1' }
         )
    assert_routing(
           { :method => 'get', :path => "/attachments/download/1/filename.ext" },
           { :controller => 'attachments', :action => 'download', :id => '1',
             :filename => 'filename.ext' }
         )
  end

  def test_boards
    assert_routing(
        { :method => 'get', :path => "/projects/world_domination/boards" },
        { :controller => 'boards', :action => 'index', :project_id => 'world_domination' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/world_domination/boards/new" },
        { :controller => 'boards', :action => 'new', :project_id => 'world_domination' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/world_domination/boards/44" },
        { :controller => 'boards', :action => 'show', :project_id => 'world_domination',
          :id => '44' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/world_domination/boards/44.atom" },
        { :controller => 'boards', :action => 'show', :project_id => 'world_domination',
          :id => '44', :format => 'atom' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/world_domination/boards/44/edit" },
        { :controller => 'boards', :action => 'edit', :project_id => 'world_domination',
          :id => '44' }
      )
    assert_routing(
        { :method => 'post', :path => "/projects/world_domination/boards" },
        { :controller => 'boards', :action => 'create', :project_id => 'world_domination' }
      )
    assert_routing(
        { :method => 'put', :path => "/projects/world_domination/boards/44" },
        { :controller => 'boards', :action => 'update', :project_id => 'world_domination', :id => '44' }
      )
    assert_routing(
        { :method => 'delete', :path => "/projects/world_domination/boards/44" },
        { :controller => 'boards', :action => 'destroy', :project_id => 'world_domination', :id => '44' }
      )
  end

  def test_custom_fields
    assert_routing(
        { :method => 'get', :path => "/custom_fields" },
        { :controller => 'custom_fields', :action => 'index' }
      )
    assert_routing(
        { :method => 'get', :path => "/custom_fields/new" },
        { :controller => 'custom_fields', :action => 'new' }
      )
    assert_routing(
        { :method => 'post', :path => "/custom_fields" },
        { :controller => 'custom_fields', :action => 'create' }
      )
    assert_routing(
        { :method => 'get', :path => "/custom_fields/2/edit" },
        { :controller => 'custom_fields', :action => 'edit', :id => '2' }
      )
    assert_routing(
        { :method => 'put', :path => "/custom_fields/2" },
        { :controller => 'custom_fields', :action => 'update', :id => '2' }
      )
    assert_routing(
        { :method => 'delete', :path => "/custom_fields/2" },
        { :controller => 'custom_fields', :action => 'destroy', :id => '2' }
      )
  end

  def test_documents
    assert_routing(
        { :method => 'get', :path => "/projects/567/documents" },
        { :controller => 'documents', :action => 'index', :project_id => '567' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/567/documents/new" },
        { :controller => 'documents', :action => 'new', :project_id => '567' }
      )
    assert_routing(
        { :method => 'get', :path => "/documents/22" },
        { :controller => 'documents', :action => 'show', :id => '22' }
      )
    assert_routing(
        { :method => 'get', :path => "/documents/22/edit" },
        { :controller => 'documents', :action => 'edit', :id => '22' }
      )
    assert_routing(
        { :method => 'post', :path => "/projects/567/documents" },
        { :controller => 'documents', :action => 'create', :project_id => '567' }
      )
    assert_routing(
        { :method => 'put', :path => "/documents/22" },
        { :controller => 'documents', :action => 'update', :id => '22' }
      )
    assert_routing(
        { :method => 'delete', :path => "/documents/22" },
        { :controller => 'documents', :action => 'destroy', :id => '22' }
      )
    assert_routing(
        { :method => 'post', :path => "/documents/22/add_attachment" },
        { :controller => 'documents', :action => 'add_attachment', :id => '22' }
      )
  end

  context "roles" do
    should_route :get, "/enumerations", :controller => 'enumerations', :action => 'index'
    should_route :get, "/enumerations/new", :controller => 'enumerations', :action => 'new'
    should_route :post, "/enumerations", :controller => 'enumerations', :action => 'create'
    should_route :get, "/enumerations/2/edit", :controller => 'enumerations', :action => 'edit', :id => 2
    should_route :put, "/enumerations/2", :controller => 'enumerations', :action => 'update', :id => 2
    should_route :delete, "/enumerations/2", :controller => 'enumerations', :action => 'destroy', :id => 2
  end

  def test_groups
    assert_routing(
        { :method => 'post', :path => "/groups/567/users" },
        { :controller => 'groups', :action => 'add_users', :id => '567' }
      )
    assert_routing(
        { :method => 'delete', :path => "/groups/567/users/12" },
        { :controller => 'groups', :action => 'remove_user', :id => '567',
          :user_id => '12' }
      )
  end

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
        { :method => 'get', :path => "/projects/23/issues/new" },
        { :controller => 'issues', :action => 'new', :project_id => '23' }
      )
  end

  def test_issues_form_update
    assert_routing(
        { :method => 'post', :path => "/projects/23/issues/new" },
        { :controller => 'issues', :action => 'new', :project_id => '23' }
      )
    assert_routing(
        { :method => 'post', :path => "/projects/23/issues" },
        { :controller => 'issues', :action => 'create', :project_id => '23' }
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

  context "issues" do
    # Extra actions
    should_route :get, "/projects/23/issues/64/copy", :controller => 'issues', :action => 'new', :project_id => '23', :copy_from => '64'

    should_route :get, "/issues/move/new", :controller => 'issue_moves', :action => 'new'
    should_route :post, "/issues/move", :controller => 'issue_moves', :action => 'create'

    should_route :post, "/issues/1/quoted", :controller => 'journals', :action => 'new', :id => '1'

    should_route :get, "/issues/calendar", :controller => 'calendars', :action => 'show'
    should_route :get, "/projects/project-name/issues/calendar", :controller => 'calendars', :action => 'show', :project_id => 'project-name'

    should_route :get, "/issues/gantt", :controller => 'gantts', :action => 'show'
    should_route :get, "/issues/gantt.pdf", :controller => 'gantts', :action => 'show', :format => 'pdf'
    should_route :get, "/projects/project-name/issues/gantt", :controller => 'gantts', :action => 'show', :project_id => 'project-name'
    should_route :get, "/projects/project-name/issues/gantt.pdf", :controller => 'gantts', :action => 'show', :project_id => 'project-name', :format => 'pdf'

    should_route :get, "/issues/auto_complete", :controller => 'auto_completes', :action => 'issues'

    should_route :get, "/issues/preview/123", :controller => 'previews', :action => 'issue', :id => '123'
    should_route :post, "/issues/preview/123", :controller => 'previews', :action => 'issue', :id => '123'
    should_route :get, "/issues/context_menu", :controller => 'context_menus', :action => 'issues'
    should_route :post, "/issues/context_menu", :controller => 'context_menus', :action => 'issues'

    should_route :get, "/issues/changes", :controller => 'journals', :action => 'index'

    should_route :get, "/issues/bulk_edit", :controller => 'issues', :action => 'bulk_edit'
    should_route :post, "/issues/bulk_update", :controller => 'issues', :action => 'bulk_update'
  end

  context "issue categories" do
    should_route :get, "/projects/foo/issue_categories", :controller => 'issue_categories', :action => 'index', :project_id => 'foo'
    should_route :get, "/projects/foo/issue_categories.xml", :controller => 'issue_categories', :action => 'index', :project_id => 'foo', :format => 'xml'
    should_route :get, "/projects/foo/issue_categories.json", :controller => 'issue_categories', :action => 'index', :project_id => 'foo', :format => 'json'

    should_route :get, "/projects/foo/issue_categories/new", :controller => 'issue_categories', :action => 'new', :project_id => 'foo'

    should_route :post, "/projects/foo/issue_categories", :controller => 'issue_categories', :action => 'create', :project_id => 'foo'
    should_route :post, "/projects/foo/issue_categories.xml", :controller => 'issue_categories', :action => 'create', :project_id => 'foo', :format => 'xml'
    should_route :post, "/projects/foo/issue_categories.json", :controller => 'issue_categories', :action => 'create', :project_id => 'foo', :format => 'json'

    should_route :get, "/issue_categories/1", :controller => 'issue_categories', :action => 'show', :id => '1'
    should_route :get, "/issue_categories/1.xml", :controller => 'issue_categories', :action => 'show', :id => '1', :format => 'xml'
    should_route :get, "/issue_categories/1.json", :controller => 'issue_categories', :action => 'show', :id => '1', :format => 'json'

    should_route :get, "/issue_categories/1/edit", :controller => 'issue_categories', :action => 'edit', :id => '1'

    should_route :put, "/issue_categories/1", :controller => 'issue_categories', :action => 'update', :id => '1'
    should_route :put, "/issue_categories/1.xml", :controller => 'issue_categories', :action => 'update', :id => '1', :format => 'xml'
    should_route :put, "/issue_categories/1.json", :controller => 'issue_categories', :action => 'update', :id => '1', :format => 'json'

    should_route :delete, "/issue_categories/1", :controller => 'issue_categories', :action => 'destroy', :id => '1'
    should_route :delete, "/issue_categories/1.xml", :controller => 'issue_categories', :action => 'destroy', :id => '1', :format => 'xml'
    should_route :delete, "/issue_categories/1.json", :controller => 'issue_categories', :action => 'destroy', :id => '1', :format => 'json'
  end

  context "issue relations" do
    should_route :get, "/issues/1/relations", :controller => 'issue_relations', :action => 'index', :issue_id => '1'
    should_route :get, "/issues/1/relations.xml", :controller => 'issue_relations', :action => 'index', :issue_id => '1', :format => 'xml'
    should_route :get, "/issues/1/relations.json", :controller => 'issue_relations', :action => 'index', :issue_id => '1', :format => 'json'

    should_route :post, "/issues/1/relations", :controller => 'issue_relations', :action => 'create', :issue_id => '1'
    should_route :post, "/issues/1/relations.xml", :controller => 'issue_relations', :action => 'create', :issue_id => '1', :format => 'xml'
    should_route :post, "/issues/1/relations.json", :controller => 'issue_relations', :action => 'create', :issue_id => '1', :format => 'json'

    should_route :get, "/relations/23", :controller => 'issue_relations', :action => 'show', :id => '23'
    should_route :get, "/relations/23.xml", :controller => 'issue_relations', :action => 'show', :id => '23', :format => 'xml'
    should_route :get, "/relations/23.json", :controller => 'issue_relations', :action => 'show', :id => '23', :format => 'json'

    should_route :delete, "/relations/23", :controller => 'issue_relations', :action => 'destroy', :id => '23'
    should_route :delete, "/relations/23.xml", :controller => 'issue_relations', :action => 'destroy', :id => '23', :format => 'xml'
    should_route :delete, "/relations/23.json", :controller => 'issue_relations', :action => 'destroy', :id => '23', :format => 'json'
  end

  def test_issue_reports
    assert_routing(
        { :method => 'get', :path => "/projects/567/issues/report" },
        { :controller => 'reports', :action => 'issue_report', :id => '567' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/567/issues/report/assigned_to" },
        { :controller => 'reports', :action => 'issue_report_details',
          :id => '567', :detail => 'assigned_to' }
      )
  end

  def test_members
    assert_routing(
        { :method => 'post', :path => "/projects/5234/members/new" },
        { :controller => 'members', :action => 'new', :id => '5234' }
      )
  end

  context "messages" do
    should_route :get, "/boards/22/topics/2", :controller => 'messages', :action => 'show', :id => '2', :board_id => '22'
    should_route :get, "/boards/lala/topics/new", :controller => 'messages', :action => 'new', :board_id => 'lala'
    should_route :get, "/boards/lala/topics/22/edit", :controller => 'messages', :action => 'edit', :id => '22', :board_id => 'lala'

    should_route :post, "/boards/lala/topics/new", :controller => 'messages', :action => 'new', :board_id => 'lala'
    should_route :post, "/boards/lala/topics/22/edit", :controller => 'messages', :action => 'edit', :id => '22', :board_id => 'lala'
    should_route :post, "/boards/22/topics/555/replies", :controller => 'messages', :action => 'reply', :id => '555', :board_id => '22'
    should_route :post, "/boards/22/topics/555/destroy", :controller => 'messages', :action => 'destroy', :id => '555', :board_id => '22'
  end

  context "news" do
    should_route :get, "/news", :controller => 'news', :action => 'index'
    should_route :get, "/news.atom", :controller => 'news', :action => 'index', :format => 'atom'
    should_route :get, "/news.xml", :controller => 'news', :action => 'index', :format => 'xml'
    should_route :get, "/news.json", :controller => 'news', :action => 'index', :format => 'json'
    should_route :get, "/projects/567/news", :controller => 'news', :action => 'index', :project_id => '567'
    should_route :get, "/projects/567/news.atom", :controller => 'news', :action => 'index', :format => 'atom', :project_id => '567'
    should_route :get, "/projects/567/news.xml", :controller => 'news', :action => 'index', :format => 'xml', :project_id => '567'
    should_route :get, "/projects/567/news.json", :controller => 'news', :action => 'index', :format => 'json', :project_id => '567'
    should_route :get, "/news/2", :controller => 'news', :action => 'show', :id => '2'
    should_route :get, "/projects/567/news/new", :controller => 'news', :action => 'new', :project_id => '567'
    should_route :get, "/news/234", :controller => 'news', :action => 'show', :id => '234'
    should_route :get, "/news/567/edit", :controller => 'news', :action => 'edit', :id => '567'
    should_route :get, "/news/preview", :controller => 'previews', :action => 'news'

    should_route :post, "/projects/567/news", :controller => 'news', :action => 'create', :project_id => '567'
    should_route :post, "/news/567/comments", :controller => 'comments', :action => 'create', :id => '567'

    should_route :put, "/news/567", :controller => 'news', :action => 'update', :id => '567'

    should_route :delete, "/news/567", :controller => 'news', :action => 'destroy', :id => '567'
    should_route :delete, "/news/567/comments/15", :controller => 'comments', :action => 'destroy', :id => '567', :comment_id => '15'
  end

  context "projects" do
    should_route :get, "/projects", :controller => 'projects', :action => 'index'
    should_route :get, "/projects.atom", :controller => 'projects', :action => 'index', :format => 'atom'
    should_route :get, "/projects.xml", :controller => 'projects', :action => 'index', :format => 'xml'
    should_route :get, "/projects/new", :controller => 'projects', :action => 'new'
    should_route :get, "/projects/test", :controller => 'projects', :action => 'show', :id => 'test'
    should_route :get, "/projects/1.xml", :controller => 'projects', :action => 'show', :id => '1', :format => 'xml'
    should_route :get, "/projects/4223/settings", :controller => 'projects', :action => 'settings', :id => '4223'
    should_route :get, "/projects/4223/settings/members", :controller => 'projects', :action => 'settings', :id => '4223', :tab => 'members'
    should_route :get, "/projects/33/files", :controller => 'files', :action => 'index', :project_id => '33'
    should_route :get, "/projects/33/files/new", :controller => 'files', :action => 'new', :project_id => '33'
    should_route :get, "/projects/33/roadmap", :controller => 'versions', :action => 'index', :project_id => '33'
    should_route :get, "/projects/33/activity", :controller => 'activities', :action => 'index', :id => '33'
    should_route :get, "/projects/33/activity.atom", :controller => 'activities', :action => 'index', :id => '33', :format => 'atom'

    should_route :post, "/projects", :controller => 'projects', :action => 'create'
    should_route :post, "/projects.xml", :controller => 'projects', :action => 'create', :format => 'xml'
    should_route :post, "/projects/33/files", :controller => 'files', :action => 'create', :project_id => '33'
    should_route :post, "/projects/64/archive", :controller => 'projects', :action => 'archive', :id => '64'
    should_route :post, "/projects/64/unarchive", :controller => 'projects', :action => 'unarchive', :id => '64'

    should_route :put, "/projects/64/enumerations", :controller => 'project_enumerations', :action => 'update', :project_id => '64'
    should_route :put, "/projects/4223", :controller => 'projects', :action => 'update', :id => '4223'
    should_route :put, "/projects/1.xml", :controller => 'projects', :action => 'update', :id => '1', :format => 'xml'

    should_route :delete, "/projects/64", :controller => 'projects', :action => 'destroy', :id => '64'
    should_route :delete, "/projects/1.xml", :controller => 'projects', :action => 'destroy', :id => '1', :format => 'xml'
    should_route :delete, "/projects/64/enumerations", :controller => 'project_enumerations', :action => 'destroy', :project_id => '64'
  end

  context "queries" do
    should_route :get, "/queries.xml", :controller => 'queries', :action => 'index', :format => 'xml'
    should_route :get, "/queries.json", :controller => 'queries', :action => 'index', :format => 'json'

    should_route :get, "/queries/new", :controller => 'queries', :action => 'new'
    should_route :get, "/projects/redmine/queries/new", :controller => 'queries', :action => 'new', :project_id => 'redmine'

    should_route :post, "/queries", :controller => 'queries', :action => 'create'
    should_route :post, "/projects/redmine/queries", :controller => 'queries', :action => 'create', :project_id => 'redmine'

    should_route :get, "/queries/1/edit", :controller => 'queries', :action => 'edit', :id => '1'

    should_route :put, "/queries/1", :controller => 'queries', :action => 'update', :id => '1'

    should_route :delete, "/queries/1", :controller => 'queries', :action => 'destroy', :id => '1'
  end

  context "repositories" do
    should_route :get, "/projects/redmine/repository", :controller => 'repositories', :action => 'show', :id => 'redmine'
    should_route :get, "/projects/redmine/repository/edit", :controller => 'repositories', :action => 'edit', :id => 'redmine'
    should_route :get, "/projects/redmine/repository/revisions", :controller => 'repositories', :action => 'revisions', :id => 'redmine'
    should_route :get, "/projects/redmine/repository/revisions.atom", :controller => 'repositories', :action => 'revisions', :id => 'redmine', :format => 'atom'
    should_route :get, "/projects/redmine/repository/revisions/2457", :controller => 'repositories', :action => 'revision', :id => 'redmine', :rev => '2457'
    should_route :get, "/projects/redmine/repository/revisions/2457/diff", :controller => 'repositories', :action => 'diff', :id => 'redmine', :rev => '2457'
    should_route :get, "/projects/redmine/repository/revisions/2457/diff.diff", :controller => 'repositories', :action => 'diff', :id => 'redmine', :rev => '2457', :format => 'diff'
    should_route :get, "/projects/redmine/repository/diff/path/to/file.c", :controller => 'repositories', :action => 'diff', :id => 'redmine', :path => %w[path to file.c]
    should_route :get, "/projects/redmine/repository/revisions/2/diff/path/to/file.c", :controller => 'repositories', :action => 'diff', :id => 'redmine', :path => %w[path to file.c], :rev => '2'
    should_route :get, "/projects/redmine/repository/browse/path/to/file.c", :controller => 'repositories', :action => 'browse', :id => 'redmine', :path => %w[path to file.c]
    should_route :get, "/projects/redmine/repository/entry/path/to/file.c", :controller => 'repositories', :action => 'entry', :id => 'redmine', :path => %w[path to file.c]
    should_route :get, "/projects/redmine/repository/revisions/2/entry/path/to/file.c", :controller => 'repositories', :action => 'entry', :id => 'redmine', :path => %w[path to file.c], :rev => '2'
    should_route :get, "/projects/redmine/repository/raw/path/to/file.c", :controller => 'repositories', :action => 'entry', :id => 'redmine', :path => %w[path to file.c], :format => 'raw'
    should_route :get, "/projects/redmine/repository/revisions/2/raw/path/to/file.c", :controller => 'repositories', :action => 'entry', :id => 'redmine', :path => %w[path to file.c], :rev => '2', :format => 'raw'
    should_route :get, "/projects/redmine/repository/annotate/path/to/file.c", :controller => 'repositories', :action => 'annotate', :id => 'redmine', :path => %w[path to file.c]
    should_route :get, "/projects/redmine/repository/changes/path/to/file.c", :controller => 'repositories', :action => 'changes', :id => 'redmine', :path => %w[path to file.c]
    should_route :get, "/projects/redmine/repository/statistics", :controller => 'repositories', :action => 'stats', :id => 'redmine'

    should_route :post, "/projects/redmine/repository/edit", :controller => 'repositories', :action => 'edit', :id => 'redmine'
  end

  context "roles" do
    should_route :get, "/roles", :controller => 'roles', :action => 'index'
    should_route :get, "/roles/new", :controller => 'roles', :action => 'new'
    should_route :post, "/roles", :controller => 'roles', :action => 'create'
    should_route :get, "/roles/2/edit", :controller => 'roles', :action => 'edit', :id => 2
    should_route :put, "/roles/2", :controller => 'roles', :action => 'update', :id => 2
    should_route :delete, "/roles/2", :controller => 'roles', :action => 'destroy', :id => 2
    should_route :get, "/roles/permissions", :controller => 'roles', :action => 'permissions'
    should_route :post, "/roles/permissions", :controller => 'roles', :action => 'permissions'
  end

  context "timelogs (global)" do
    should_route :get, "/time_entries", :controller => 'timelog', :action => 'index'
    should_route :get, "/time_entries.csv", :controller => 'timelog', :action => 'index', :format => 'csv'
    should_route :get, "/time_entries.atom", :controller => 'timelog', :action => 'index', :format => 'atom'
    should_route :get, "/time_entries/new", :controller => 'timelog', :action => 'new'
    should_route :get, "/time_entries/22/edit", :controller => 'timelog', :action => 'edit', :id => '22'

    should_route :post, "/time_entries", :controller => 'timelog', :action => 'create'

    should_route :put, "/time_entries/22", :controller => 'timelog', :action => 'update', :id => '22'

    should_route :delete, "/time_entries/55", :controller => 'timelog', :action => 'destroy', :id => '55'
  end

  context "timelogs (scoped under project)" do
    should_route :get, "/projects/567/time_entries", :controller => 'timelog', :action => 'index', :project_id => '567'
    should_route :get, "/projects/567/time_entries.csv", :controller => 'timelog', :action => 'index', :project_id => '567', :format => 'csv'
    should_route :get, "/projects/567/time_entries.atom", :controller => 'timelog', :action => 'index', :project_id => '567', :format => 'atom'
    should_route :get, "/projects/567/time_entries/new", :controller => 'timelog', :action => 'new', :project_id => '567'
    should_route :get, "/projects/567/time_entries/22/edit", :controller => 'timelog', :action => 'edit', :id => '22', :project_id => '567'

    should_route :post, "/projects/567/time_entries", :controller => 'timelog', :action => 'create', :project_id => '567'

    should_route :put, "/projects/567/time_entries/22", :controller => 'timelog', :action => 'update', :id => '22', :project_id => '567'

    should_route :delete, "/projects/567/time_entries/55", :controller => 'timelog', :action => 'destroy', :id => '55', :project_id => '567'
  end

  context "timelogs (scoped under issues)" do
    should_route :get, "/issues/234/time_entries", :controller => 'timelog', :action => 'index', :issue_id => '234'
    should_route :get, "/issues/234/time_entries.csv", :controller => 'timelog', :action => 'index', :issue_id => '234', :format => 'csv'
    should_route :get, "/issues/234/time_entries.atom", :controller => 'timelog', :action => 'index', :issue_id => '234', :format => 'atom'
    should_route :get, "/issues/234/time_entries/new", :controller => 'timelog', :action => 'new', :issue_id => '234'
    should_route :get, "/issues/234/time_entries/22/edit", :controller => 'timelog', :action => 'edit', :id => '22', :issue_id => '234'

    should_route :post, "/issues/234/time_entries", :controller => 'timelog', :action => 'create', :issue_id => '234'

    should_route :put, "/issues/234/time_entries/22", :controller => 'timelog', :action => 'update', :id => '22', :issue_id => '234'

    should_route :delete, "/issues/234/time_entries/55", :controller => 'timelog', :action => 'destroy', :id => '55', :issue_id => '234'
  end

  context "timelogs (scoped under project and issues)" do
    should_route :get, "/projects/ecookbook/issues/234/time_entries", :controller => 'timelog', :action => 'index', :issue_id => '234', :project_id => 'ecookbook'
    should_route :get, "/projects/ecookbook/issues/234/time_entries.csv", :controller => 'timelog', :action => 'index', :issue_id => '234', :project_id => 'ecookbook', :format => 'csv'
    should_route :get, "/projects/ecookbook/issues/234/time_entries.atom", :controller => 'timelog', :action => 'index', :issue_id => '234', :project_id => 'ecookbook', :format => 'atom'
    should_route :get, "/projects/ecookbook/issues/234/time_entries/new", :controller => 'timelog', :action => 'new', :issue_id => '234', :project_id => 'ecookbook'
    should_route :get, "/projects/ecookbook/issues/234/time_entries/22/edit", :controller => 'timelog', :action => 'edit', :id => '22', :issue_id => '234', :project_id => 'ecookbook'

    should_route :post, "/projects/ecookbook/issues/234/time_entries", :controller => 'timelog', :action => 'create', :issue_id => '234', :project_id => 'ecookbook'

    should_route :put, "/projects/ecookbook/issues/234/time_entries/22", :controller => 'timelog', :action => 'update', :id => '22', :issue_id => '234', :project_id => 'ecookbook'

    should_route :delete, "/projects/ecookbook/issues/234/time_entries/55", :controller => 'timelog', :action => 'destroy', :id => '55', :issue_id => '234', :project_id => 'ecookbook'

    should_route :get, "/time_entries/report", :controller => 'timelog', :action => 'report'
    should_route :get, "/projects/567/time_entries/report", :controller => 'timelog', :action => 'report', :project_id => '567'
    should_route :get, "/projects/567/time_entries/report.csv", :controller => 'timelog', :action => 'report', :project_id => '567', :format => 'csv'
  end

  context "users" do
    should_route :get, "/users", :controller => 'users', :action => 'index'
    should_route :get, "/users.xml", :controller => 'users', :action => 'index', :format => 'xml'
    should_route :get, "/users/44", :controller => 'users', :action => 'show', :id => '44'
    should_route :get, "/users/44.xml", :controller => 'users', :action => 'show', :id => '44', :format => 'xml'
    should_route :get, "/users/current", :controller => 'users', :action => 'show', :id => 'current'
    should_route :get, "/users/current.xml", :controller => 'users', :action => 'show', :id => 'current', :format => 'xml'
    should_route :get, "/users/new", :controller => 'users', :action => 'new'
    should_route :get, "/users/444/edit", :controller => 'users', :action => 'edit', :id => '444'

    should_route :post, "/users", :controller => 'users', :action => 'create'
    should_route :post, "/users.xml", :controller => 'users', :action => 'create', :format => 'xml'

    should_route :put, "/users/444", :controller => 'users', :action => 'update', :id => '444'
    should_route :put, "/users/444.xml", :controller => 'users', :action => 'update', :id => '444', :format => 'xml'

    should_route :delete, "/users/44", :controller => 'users', :action => 'destroy', :id => '44'
    should_route :delete, "/users/44.xml", :controller => 'users', :action => 'destroy', :id => '44', :format => 'xml'

    should_route :post, "/users/123/memberships", :controller => 'users', :action => 'edit_membership', :id => '123'
    should_route :put, "/users/123/memberships/55", :controller => 'users', :action => 'edit_membership', :id => '123', :membership_id => '55'
    should_route :delete, "/users/123/memberships/55", :controller => 'users', :action => 'destroy_membership', :id => '123', :membership_id => '55'
  end

  context "versions" do
    # /projects/foo/versions is /projects/foo/roadmap
    should_route :get, "/projects/foo/versions.xml", :controller => 'versions', :action => 'index', :project_id => 'foo', :format => 'xml'
    should_route :get, "/projects/foo/versions.json", :controller => 'versions', :action => 'index', :project_id => 'foo', :format => 'json'

    should_route :get, "/projects/foo/versions/new", :controller => 'versions', :action => 'new', :project_id => 'foo'

    should_route :post, "/projects/foo/versions", :controller => 'versions', :action => 'create', :project_id => 'foo'
    should_route :post, "/projects/foo/versions.xml", :controller => 'versions', :action => 'create', :project_id => 'foo', :format => 'xml'
    should_route :post, "/projects/foo/versions.json", :controller => 'versions', :action => 'create', :project_id => 'foo', :format => 'json'

    should_route :get, "/versions/1", :controller => 'versions', :action => 'show', :id => '1'
    should_route :get, "/versions/1.xml", :controller => 'versions', :action => 'show', :id => '1', :format => 'xml'
    should_route :get, "/versions/1.json", :controller => 'versions', :action => 'show', :id => '1', :format => 'json'

    should_route :get, "/versions/1/edit", :controller => 'versions', :action => 'edit', :id => '1'

    should_route :put, "/versions/1", :controller => 'versions', :action => 'update', :id => '1'
    should_route :put, "/versions/1.xml", :controller => 'versions', :action => 'update', :id => '1', :format => 'xml'
    should_route :put, "/versions/1.json", :controller => 'versions', :action => 'update', :id => '1', :format => 'json'

    should_route :delete, "/versions/1", :controller => 'versions', :action => 'destroy', :id => '1'
    should_route :delete, "/versions/1.xml", :controller => 'versions', :action => 'destroy', :id => '1', :format => 'xml'
    should_route :delete, "/versions/1.json", :controller => 'versions', :action => 'destroy', :id => '1', :format => 'json'

    should_route :put, "/projects/foo/versions/close_completed", :controller => 'versions', :action => 'close_completed', :project_id => 'foo'
    should_route :post, "/versions/1/status_by", :controller => 'versions', :action => 'status_by', :id => '1'
  end

  def test_welcome
    assert_routing(
        { :method => 'get', :path => "/robots.txt" },
        { :controller => 'welcome', :action => 'robots' }
      )
  end

  context "wiki (singular, project's pages)" do
    should_route :get, "/projects/567/wiki", :controller => 'wiki', :action => 'show', :project_id => '567'
    should_route :get, "/projects/567/wiki/lalala", :controller => 'wiki', :action => 'show', :project_id => '567', :id => 'lalala'
    should_route :get, "/projects/567/wiki/my_page/edit", :controller => 'wiki', :action => 'edit', :project_id => '567', :id => 'my_page'
    should_route :get, "/projects/1/wiki/CookBook_documentation/history", :controller => 'wiki', :action => 'history', :project_id => '1', :id => 'CookBook_documentation'
    should_route :get, "/projects/1/wiki/CookBook_documentation/diff", :controller => 'wiki', :action => 'diff', :project_id => '1', :id => 'CookBook_documentation'
    should_route :get, "/projects/1/wiki/CookBook_documentation/diff/2", :controller => 'wiki', :action => 'diff', :project_id => '1', :id => 'CookBook_documentation', :version => '2'
    should_route :get, "/projects/1/wiki/CookBook_documentation/diff/2/vs/1", :controller => 'wiki', :action => 'diff', :project_id => '1', :id => 'CookBook_documentation', :version => '2', :version_from => '1'
    should_route :get, "/projects/1/wiki/CookBook_documentation/annotate/2", :controller => 'wiki', :action => 'annotate', :project_id => '1', :id => 'CookBook_documentation', :version => '2'
    should_route :get, "/projects/22/wiki/ladida/rename", :controller => 'wiki', :action => 'rename', :project_id => '22', :id => 'ladida'
    should_route :get, "/projects/567/wiki/index", :controller => 'wiki', :action => 'index', :project_id => '567'
    should_route :get, "/projects/567/wiki/date_index", :controller => 'wiki', :action => 'date_index', :project_id => '567'
    should_route :get, "/projects/567/wiki/export", :controller => 'wiki', :action => 'export', :project_id => '567'

    should_route :post, "/projects/567/wiki/CookBook_documentation/preview", :controller => 'wiki', :action => 'preview', :project_id => '567', :id => 'CookBook_documentation'
    should_route :post, "/projects/22/wiki/ladida/rename", :controller => 'wiki', :action => 'rename', :project_id => '22', :id => 'ladida'
    should_route :post, "/projects/22/wiki/ladida/protect", :controller => 'wiki', :action => 'protect', :project_id => '22', :id => 'ladida'
    should_route :post, "/projects/22/wiki/ladida/add_attachment", :controller => 'wiki', :action => 'add_attachment', :project_id => '22', :id => 'ladida'

    should_route :put, "/projects/567/wiki/my_page", :controller => 'wiki', :action => 'update', :project_id => '567', :id => 'my_page'

    should_route :delete, "/projects/22/wiki/ladida", :controller => 'wiki', :action => 'destroy', :project_id => '22', :id => 'ladida'
  end

  def test_wikis_plural_admin_setup
    assert_routing(
        { :method => 'get', :path => "/projects/ladida/wiki/destroy" },
        { :controller => 'wikis', :action => 'destroy', :id => 'ladida' }
      )
    assert_routing(
        { :method => 'post', :path => "/projects/ladida/wiki" },
        { :controller => 'wikis', :action => 'edit', :id => 'ladida' }
      )
    assert_routing(
        { :method => 'post', :path => "/projects/ladida/wiki/destroy" },
        { :controller => 'wikis', :action => 'destroy', :id => 'ladida' }
      )
  end

  def test_administration_panel
    assert_routing(
        { :method => 'get', :path => "/admin/projects" },
        { :controller => 'admin', :action => 'projects' }
      )
  end
end
