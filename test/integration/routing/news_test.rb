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

class RoutingNewsTest < Redmine::RoutingTest
  def test_news_scoped_under_project
    should_route 'GET /projects/foo/news' => 'news#index', :project_id => 'foo'
    should_route 'GET /projects/foo/news.atom' => 'news#index', :project_id => 'foo', :format => 'atom'
    should_route 'GET /projects/foo/news/new' => 'news#new', :project_id => 'foo'
    should_route 'POST /projects/foo/news' => 'news#create', :project_id => 'foo'
  end

  def test_news
    should_route 'GET /news' => 'news#index'
    should_route 'GET /news.atom' => 'news#index', :format => 'atom'
    should_route 'GET /news/2' => 'news#show', :id => '2'
    should_route 'GET /news/2/edit' => 'news#edit', :id => '2'
    should_route 'PUT /news/2' => 'news#update', :id => '2'
    should_route 'DELETE /news/2' => 'news#destroy', :id => '2'
  end
end
