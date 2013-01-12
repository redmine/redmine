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

class RoutingBoardsTest < ActionController::IntegrationTest
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
        { :controller => 'boards', :action => 'update', :project_id => 'world_domination',
          :id => '44' }
      )
    assert_routing(
        { :method => 'delete', :path => "/projects/world_domination/boards/44" },
        { :controller => 'boards', :action => 'destroy', :project_id => 'world_domination',
          :id => '44' }
      )
  end
end
