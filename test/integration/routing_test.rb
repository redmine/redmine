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

  def test_issues_extra_actions
    assert_routing(
        { :method => 'get', :path => "/projects/23/issues/64/copy" },
        { :controller => 'issues', :action => 'new', :project_id => '23',
          :copy_from => '64' }
      )
    assert_routing(
        { :method => 'get', :path => "/issues/preview/123" },
        { :controller => 'previews', :action => 'issue', :id => '123' }
      )
    assert_routing(
        { :method => 'post', :path => "/issues/preview/123" },
        { :controller => 'previews', :action => 'issue', :id => '123' }
      )
    assert_routing(
        { :method => 'get', :path => "/issues/context_menu" },
        { :controller => 'context_menus', :action => 'issues' }
      )
    assert_routing(
        { :method => 'post', :path => "/issues/context_menu" },
        { :controller => 'context_menus', :action => 'issues' }
      )
    assert_routing(
        { :method => 'get', :path => "/issues/bulk_edit" },
        { :controller => 'issues', :action => 'bulk_edit' }
      )
    assert_routing(
        { :method => 'post', :path => "/issues/bulk_update" },
        { :controller => 'issues', :action => 'bulk_update' }
      )
  end

  def test_issue_categories
    assert_routing(
        { :method => 'get', :path => "/projects/foo/issue_categories" },
        { :controller => 'issue_categories', :action => 'index',
          :project_id => 'foo' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/foo/issue_categories.xml" },
        { :controller => 'issue_categories', :action => 'index',
          :project_id => 'foo', :format => 'xml' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/foo/issue_categories.json" },
        { :controller => 'issue_categories', :action => 'index',
          :project_id => 'foo', :format => 'json' }
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
    assert_routing(
        { :method => 'post', :path => "/projects/foo/issue_categories.xml" },
        { :controller => 'issue_categories', :action => 'create',
          :project_id => 'foo', :format => 'xml' }
      )
    assert_routing(
        { :method => 'post', :path => "/projects/foo/issue_categories.json" },
        { :controller => 'issue_categories', :action => 'create',
          :project_id => 'foo', :format => 'json' }
      )
    assert_routing(
        { :method => 'get', :path => "/issue_categories/1" },
        { :controller => 'issue_categories', :action => 'show', :id => '1' }
      )
    assert_routing(
        { :method => 'get', :path => "/issue_categories/1.xml" },
        { :controller => 'issue_categories', :action => 'show', :id => '1',
          :format => 'xml' }
      )
    assert_routing(
        { :method => 'get', :path => "/issue_categories/1.json" },
        { :controller => 'issue_categories', :action => 'show', :id => '1',
          :format => 'json' }
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
        { :method => 'put', :path => "/issue_categories/1.xml" },
        { :controller => 'issue_categories', :action => 'update', :id => '1',
          :format => 'xml' }
      )
    assert_routing(
        { :method => 'put', :path => "/issue_categories/1.json" },
        { :controller => 'issue_categories', :action => 'update', :id => '1',
          :format => 'json' }
      )
    assert_routing(
        { :method => 'delete', :path => "/issue_categories/1" },
        { :controller => 'issue_categories', :action => 'destroy', :id => '1' }
      )
    assert_routing(
        { :method => 'delete', :path => "/issue_categories/1.xml" },
        { :controller => 'issue_categories', :action => 'destroy', :id => '1',
          :format => 'xml' }
      )
    assert_routing(
        { :method => 'delete', :path => "/issue_categories/1.json" },
        { :controller => 'issue_categories', :action => 'destroy', :id => '1',
          :format => 'json' }
      )
  end

  def test_news
    assert_routing(
        { :method => 'get', :path => "/news" },
        { :controller => 'news', :action => 'index' }
      )
    assert_routing(
        { :method => 'get', :path => "/news.atom" },
        { :controller => 'news', :action => 'index', :format => 'atom' }
      )
    assert_routing(
        { :method => 'get', :path => "/news.xml" },
        { :controller => 'news', :action => 'index', :format => 'xml' }
      )
    assert_routing(
        { :method => 'get', :path => "/news.json" },
        { :controller => 'news', :action => 'index', :format => 'json' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/567/news" },
        { :controller => 'news', :action => 'index', :project_id => '567' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/567/news.atom" },
        { :controller => 'news', :action => 'index', :format => 'atom',
          :project_id => '567' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/567/news.xml" },
        { :controller => 'news', :action => 'index', :format => 'xml',
          :project_id => '567' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/567/news.json" },
        { :controller => 'news', :action => 'index', :format => 'json',
          :project_id => '567' }
      )
    assert_routing(
        { :method => 'get', :path => "/news/2" },
        { :controller => 'news', :action => 'show', :id => '2' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/567/news/new" },
        { :controller => 'news', :action => 'new', :project_id => '567' }
      )
    assert_routing(
        { :method => 'get', :path => "/news/234" },
        { :controller => 'news', :action => 'show', :id => '234' }
      )
    assert_routing(
        { :method => 'get', :path => "/news/567/edit" },
        { :controller => 'news', :action => 'edit', :id => '567' }
      )
    assert_routing(
        { :method => 'get', :path => "/news/preview" },
        { :controller => 'previews', :action => 'news' }
      )
    assert_routing(
        { :method => 'post', :path => "/projects/567/news" },
        { :controller => 'news', :action => 'create', :project_id => '567' }
      )
    assert_routing(
        { :method => 'post', :path => "/news/567/comments" },
        { :controller => 'comments', :action => 'create', :id => '567' }
      )
    assert_routing(
        { :method => 'put', :path => "/news/567" },
        { :controller => 'news', :action => 'update', :id => '567' }
      )
    assert_routing(
        { :method => 'delete', :path => "/news/567" },
        { :controller => 'news', :action => 'destroy', :id => '567' }
      )
    assert_routing(
        { :method => 'delete', :path => "/news/567/comments/15" },
        { :controller => 'comments', :action => 'destroy', :id => '567',
          :comment_id => '15' }
      )
  end

  def test_projects
    assert_routing(
        { :method => 'get', :path => "/projects" },
        { :controller => 'projects', :action => 'index' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects.atom" },
        { :controller => 'projects', :action => 'index', :format => 'atom' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects.xml" },
        { :controller => 'projects', :action => 'index', :format => 'xml' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/new" },
        { :controller => 'projects', :action => 'new' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/test" },
        { :controller => 'projects', :action => 'show', :id => 'test' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/1.xml" },
        { :controller => 'projects', :action => 'show', :id => '1',
          :format => 'xml' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/4223/settings" },
        { :controller => 'projects', :action => 'settings', :id => '4223' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/4223/settings/members" },
        { :controller => 'projects', :action => 'settings', :id => '4223',
          :tab => 'members' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/33/roadmap" },
        { :controller => 'versions', :action => 'index', :project_id => '33' }
      )
    assert_routing(
        { :method => 'post', :path => "/projects" },
        { :controller => 'projects', :action => 'create' }
      )
    assert_routing(
        { :method => 'post', :path => "/projects.xml" },
        { :controller => 'projects', :action => 'create', :format => 'xml' }
      )
    assert_routing(
        { :method => 'post', :path => "/projects/64/archive" },
        { :controller => 'projects', :action => 'archive', :id => '64' }
      )
    assert_routing(
        { :method => 'post', :path => "/projects/64/unarchive" },
        { :controller => 'projects', :action => 'unarchive', :id => '64' }
      )
    assert_routing(
        { :method => 'put', :path => "/projects/64/enumerations" },
        { :controller => 'project_enumerations', :action => 'update',
          :project_id => '64' }
      )
    assert_routing(
        { :method => 'put', :path => "/projects/4223" },
        { :controller => 'projects', :action => 'update', :id => '4223' }
      )
    assert_routing(
        { :method => 'put', :path => "/projects/1.xml" },
        { :controller => 'projects', :action => 'update', :id => '1',
          :format => 'xml' }
      )
    assert_routing(
        { :method => 'delete', :path => "/projects/64" },
        { :controller => 'projects', :action => 'destroy', :id => '64' }
      )
    assert_routing(
        { :method => 'delete', :path => "/projects/1.xml" },
        { :controller => 'projects', :action => 'destroy', :id => '1',
          :format => 'xml' }
      )
    assert_routing(
        { :method => 'delete', :path => "/projects/64/enumerations" },
        { :controller => 'project_enumerations', :action => 'destroy',
          :project_id => '64' }
      )
  end

  def test_queries
    assert_routing(
        { :method => 'get', :path => "/queries.xml" },
        { :controller => 'queries', :action => 'index', :format => 'xml' }
      )
    assert_routing(
        { :method => 'get', :path => "/queries.json" },
        { :controller => 'queries', :action => 'index', :format => 'json' }
      )
    assert_routing(
        { :method => 'get', :path => "/queries/new" },
        { :controller => 'queries', :action => 'new' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/redmine/queries/new" },
        { :controller => 'queries', :action => 'new', :project_id => 'redmine' }
      )
    assert_routing(
        { :method => 'post', :path => "/queries" },
        { :controller => 'queries', :action => 'create' }
      )
    assert_routing(
        { :method => 'post', :path => "/projects/redmine/queries" },
        { :controller => 'queries', :action => 'create', :project_id => 'redmine' }
      )
    assert_routing(
        { :method => 'get', :path => "/queries/1/edit" },
        { :controller => 'queries', :action => 'edit', :id => '1' }
      )
    assert_routing(
        { :method => 'put', :path => "/queries/1" },
        { :controller => 'queries', :action => 'update', :id => '1' }
      )
    assert_routing(
        { :method => 'delete', :path => "/queries/1" },
        { :controller => 'queries', :action => 'destroy', :id => '1' }
      )
  end

  def test_wiki_singular_projects_pages
    assert_routing(
        { :method => 'get', :path => "/projects/567/wiki" },
        { :controller => 'wiki', :action => 'show', :project_id => '567' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/567/wiki/lalala" },
        { :controller => 'wiki', :action => 'show', :project_id => '567',
          :id => 'lalala' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/567/wiki/my_page/edit" },
        { :controller => 'wiki', :action => 'edit', :project_id => '567',
          :id => 'my_page' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/1/wiki/CookBook_documentation/history" },
        { :controller => 'wiki', :action => 'history', :project_id => '1',
          :id => 'CookBook_documentation' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/1/wiki/CookBook_documentation/diff" },
        { :controller => 'wiki', :action => 'diff', :project_id => '1',
          :id => 'CookBook_documentation' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/1/wiki/CookBook_documentation/diff/2" },
        { :controller => 'wiki', :action => 'diff', :project_id => '1',
          :id => 'CookBook_documentation', :version => '2' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/1/wiki/CookBook_documentation/diff/2/vs/1" },
        { :controller => 'wiki', :action => 'diff', :project_id => '1',
          :id => 'CookBook_documentation', :version => '2', :version_from => '1' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/1/wiki/CookBook_documentation/annotate/2" },
        { :controller => 'wiki', :action => 'annotate', :project_id => '1',
          :id => 'CookBook_documentation', :version => '2' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/22/wiki/ladida/rename" },
        { :controller => 'wiki', :action => 'rename', :project_id => '22',
          :id => 'ladida' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/567/wiki/index" },
        { :controller => 'wiki', :action => 'index', :project_id => '567' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/567/wiki/date_index" },
        { :controller => 'wiki', :action => 'date_index', :project_id => '567' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/567/wiki/export" },
        { :controller => 'wiki', :action => 'export', :project_id => '567' }
      )
    assert_routing(
        { :method => 'post', :path => "/projects/567/wiki/CookBook_documentation/preview" },
        { :controller => 'wiki', :action => 'preview', :project_id => '567',
          :id => 'CookBook_documentation' }
      )
    assert_routing(
        { :method => 'post', :path => "/projects/22/wiki/ladida/rename" },
        { :controller => 'wiki', :action => 'rename', :project_id => '22',
          :id => 'ladida' }
      )
    assert_routing(
        { :method => 'post', :path => "/projects/22/wiki/ladida/protect" },
        { :controller => 'wiki', :action => 'protect', :project_id => '22',
          :id => 'ladida' }
      )
    assert_routing(
        { :method => 'post', :path => "/projects/22/wiki/ladida/add_attachment" },
        { :controller => 'wiki', :action => 'add_attachment', :project_id => '22',
          :id => 'ladida' }
      )
    assert_routing(
        { :method => 'put', :path => "/projects/567/wiki/my_page" },
        { :controller => 'wiki', :action => 'update', :project_id => '567',
          :id => 'my_page' }
      )
    assert_routing(
        { :method => 'delete', :path => "/projects/22/wiki/ladida" },
        { :controller => 'wiki', :action => 'destroy', :project_id => '22',
          :id => 'ladida' }
      )
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
end
