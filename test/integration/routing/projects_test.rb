# Redmine - project management software
# Copyright (C) 2006-2017  Jean-Philippe Lang
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

class RoutingProjectsTest < Redmine::RoutingTest
  def test_projects
    should_route 'GET /projects' => 'projects#index'
    should_route 'GET /projects.atom' => 'projects#index', :format => 'atom'
    should_route 'GET /projects/new' => 'projects#new'
    should_route 'POST /projects' => 'projects#create'

    should_route 'GET /projects/autocomplete.js' => 'projects#autocomplete', :format => 'js'

    should_route 'GET /projects/foo' => 'projects#show', :id => 'foo'
    should_route 'PUT /projects/foo' => 'projects#update', :id => 'foo'
    should_route 'DELETE /projects/foo' => 'projects#destroy', :id => 'foo'

    should_route 'GET /projects/foo/settings' => 'projects#settings', :id => 'foo'
    should_route 'GET /projects/foo/settings/members' => 'projects#settings', :id => 'foo', :tab => 'members'

    should_route 'POST /projects/foo/archive' => 'projects#archive', :id => 'foo'
    should_route 'POST /projects/foo/unarchive' => 'projects#unarchive', :id => 'foo'
    should_route 'POST /projects/foo/close' => 'projects#close', :id => 'foo'
    should_route 'POST /projects/foo/reopen' => 'projects#reopen', :id => 'foo'
  end
end
