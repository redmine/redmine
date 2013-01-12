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

class RoutingNewsTest < ActionController::IntegrationTest
  def test_news_index
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
  end

  def test_news
    assert_routing(
        { :method => 'get', :path => "/news/2" },
        { :controller => 'news', :action => 'show', :id => '2' }
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
        { :method => 'put', :path => "/news/567" },
        { :controller => 'news', :action => 'update', :id => '567' }
      )
    assert_routing(
        { :method => 'delete', :path => "/news/567" },
        { :controller => 'news', :action => 'destroy', :id => '567' }
      )
  end

  def test_news_scoped_under_project
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
        { :method => 'get', :path => "/projects/567/news/new" },
        { :controller => 'news', :action => 'new', :project_id => '567' }
      )
    assert_routing(
        { :method => 'post', :path => "/projects/567/news" },
        { :controller => 'news', :action => 'create', :project_id => '567' }
      )
  end
end
