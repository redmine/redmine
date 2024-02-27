# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-  Jean-Philippe Lang
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

require_relative '../../test_helper'

class RoutingBoardsTest < Redmine::RoutingTest
  def test_boards
    should_route 'GET /projects/foo/boards' => 'boards#index', :project_id => 'foo'
    should_route 'GET /projects/foo/boards/new' => 'boards#new', :project_id => 'foo'
    should_route 'POST /projects/foo/boards' => 'boards#create', :project_id => 'foo'

    should_route 'GET /projects/foo/boards/44' => 'boards#show', :project_id => 'foo', :id => '44'
    should_route 'GET /projects/foo/boards/44.atom' => 'boards#show', :project_id => 'foo', :id => '44', :format => 'atom'
    should_route 'GET /projects/foo/boards/44/edit' => 'boards#edit', :project_id => 'foo', :id => '44'
    should_route 'PUT /projects/foo/boards/44' => 'boards#update', :project_id => 'foo', :id => '44'
    should_route 'DELETE /projects/foo/boards/44' => 'boards#destroy', :project_id => 'foo', :id => '44'
  end
end
