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

class RoutingWikiTest < ActionController::IntegrationTest
  def test_wiki_matching
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
        { :method => 'get', :path => "/projects/567/wiki/lalala.pdf" },
        { :controller => 'wiki', :action => 'show', :project_id => '567',
          :id => 'lalala', :format => 'pdf' }
        )
    assert_routing(
         { :method => 'get', :path => "/projects/1/wiki/CookBook_documentation/diff" },
         { :controller => 'wiki', :action => 'diff', :project_id => '1',
           :id => 'CookBook_documentation' }
       )
    assert_routing(
         { :method => 'get', :path => "/projects/1/wiki/CookBook_documentation/2" },
         { :controller => 'wiki', :action => 'show', :project_id => '1',
           :id => 'CookBook_documentation', :version => '2' }
       )
    assert_routing(
         { :method => 'get', :path => "/projects/1/wiki/CookBook_documentation/2/diff" },
         { :controller => 'wiki', :action => 'diff', :project_id => '1',
           :id => 'CookBook_documentation', :version => '2' }
       )
    assert_routing(
         { :method => 'get', :path => "/projects/1/wiki/CookBook_documentation/2/annotate" },
         { :controller => 'wiki', :action => 'annotate', :project_id => '1',
           :id => 'CookBook_documentation', :version => '2' }
       )
    # Make sure we don't route wiki page sub-uris to let plugins handle them
    assert_raise(ActionController::RoutingError) do
      assert_recognizes({}, {:method => 'get', :path => "/projects/1/wiki/CookBook_documentation/whatever"})
    end
  end

  def test_wiki_misc
    assert_routing(
        { :method => 'get', :path => "/projects/567/wiki/date_index" },
        { :controller => 'wiki', :action => 'date_index', :project_id => '567' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/567/wiki/export" },
        { :controller => 'wiki', :action => 'export', :project_id => '567' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/567/wiki/export.pdf" },
        { :controller => 'wiki', :action => 'export', :project_id => '567', :format => 'pdf' }
      )
    assert_routing(
         { :method => 'get', :path => "/projects/567/wiki/index" },
         { :controller => 'wiki', :action => 'index', :project_id => '567' }
       )
  end

  def test_wiki_resources
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
        { :method => 'get', :path => "/projects/22/wiki/ladida/rename" },
        { :controller => 'wiki', :action => 'rename', :project_id => '22',
          :id => 'ladida' }
      )
    ["post", "put"].each do |method|
      assert_routing(
          { :method => method, :path => "/projects/567/wiki/CookBook_documentation/preview" },
          { :controller => 'wiki', :action => 'preview', :project_id => '567',
            :id => 'CookBook_documentation' }
        )
    end
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
    assert_routing(
        { :method => 'delete', :path => "/projects/22/wiki/ladida/3" },
        { :controller => 'wiki', :action => 'destroy_version', :project_id => '22',
          :id => 'ladida', :version => '3' }
      )
  end

  def test_api
    assert_routing(
        { :method => 'get', :path => "/projects/567/wiki/my_page.xml" },
        { :controller => 'wiki', :action => 'show', :project_id => '567',
          :id => 'my_page', :format => 'xml' }
        )
    assert_routing(
        { :method => 'get', :path => "/projects/567/wiki/my_page.json" },
        { :controller => 'wiki', :action => 'show', :project_id => '567',
          :id => 'my_page', :format => 'json' }
        )
    assert_routing(
         { :method => 'get', :path => "/projects/1/wiki/CookBook_documentation/2.xml" },
         { :controller => 'wiki', :action => 'show', :project_id => '1',
           :id => 'CookBook_documentation', :version => '2', :format => 'xml' }
       )
    assert_routing(
         { :method => 'get', :path => "/projects/1/wiki/CookBook_documentation/2.json" },
         { :controller => 'wiki', :action => 'show', :project_id => '1',
           :id => 'CookBook_documentation', :version => '2', :format => 'json' }
       )
    assert_routing(
         { :method => 'get', :path => "/projects/567/wiki/index.xml" },
         { :controller => 'wiki', :action => 'index', :project_id => '567', :format => 'xml' }
       )
    assert_routing(
         { :method => 'get', :path => "/projects/567/wiki/index.json" },
         { :controller => 'wiki', :action => 'index', :project_id => '567', :format => 'json' }
       )
    assert_routing(
        { :method => 'put', :path => "/projects/567/wiki/my_page.xml" },
        { :controller => 'wiki', :action => 'update', :project_id => '567',
          :id => 'my_page', :format => 'xml' }
      )
    assert_routing(
        { :method => 'put', :path => "/projects/567/wiki/my_page.json" },
        { :controller => 'wiki', :action => 'update', :project_id => '567',
          :id => 'my_page', :format => 'json' }
      )
    assert_routing(
        { :method => 'delete', :path => "/projects/567/wiki/my_page.xml" },
        { :controller => 'wiki', :action => 'destroy', :project_id => '567',
          :id => 'my_page', :format => 'xml' }
      )
    assert_routing(
        { :method => 'delete', :path => "/projects/567/wiki/my_page.json" },
        { :controller => 'wiki', :action => 'destroy', :project_id => '567',
          :id => 'my_page', :format => 'json' }
      )
  end
end
