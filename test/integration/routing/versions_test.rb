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

class RoutingVersionsTest < Redmine::RoutingTest
  def test_project_versions
    should_route 'GET /projects/foo/roadmap' => 'versions#index', :project_id => 'foo'
    should_route 'GET /projects/foo/versions/new' => 'versions#new', :project_id => 'foo'
    should_route 'POST /projects/foo/versions' => 'versions#create', :project_id => 'foo'
    should_route 'PUT /projects/foo/versions/close_completed' => 'versions#close_completed', :project_id => 'foo'
  end

  def test_versions
    should_route 'GET /versions/1' => 'versions#show', :id => '1'
    should_route 'GET /versions/1/edit' => 'versions#edit', :id => '1'
    should_route 'PUT /versions/1' => 'versions#update', :id => '1'
    should_route 'DELETE /versions/1' => 'versions#destroy', :id => '1'

    should_route 'POST /versions/1/status_by' => 'versions#status_by', :id => '1'
  end
end
