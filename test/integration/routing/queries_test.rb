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

class RoutingQueriesTest < Redmine::RoutingTest
  def test_queries
    should_route 'GET /queries/new' => 'queries#new'
    should_route 'POST /queries' => 'queries#create'
    should_route 'GET /queries/filter' => 'queries#filter'

    should_route 'GET /queries/1/edit' => 'queries#edit', :id => '1'
    should_route 'PUT /queries/1' => 'queries#update', :id => '1'
    should_route 'DELETE /queries/1' => 'queries#destroy', :id => '1'
  end

  def test_queries_scoped_under_project
    should_route 'GET /projects/foo/queries/new' => 'queries#new', :project_id => 'foo'
    should_route 'POST /projects/foo/queries' => 'queries#create', :project_id => 'foo'
  end
end
