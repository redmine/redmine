# Redmine - project management software
# Copyright (C) 2006-2015  Jean-Philippe Lang
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

class RoutingMembersTest < Redmine::RoutingTest
  def test_members
    should_route 'GET /projects/foo/memberships/new' => 'members#new', :project_id => 'foo'
    should_route 'POST /projects/foo/memberships' => 'members#create', :project_id => 'foo'

    should_route 'PUT /memberships/5234' => 'members#update', :id => '5234'
    should_route 'DELETE /memberships/5234' => 'members#destroy', :id => '5234'

    should_route 'GET /projects/foo/memberships/autocomplete' => 'members#autocomplete', :project_id => 'foo'
    should_route 'GET /projects/foo/memberships/autocomplete.js' => 'members#autocomplete', :project_id => 'foo', :format => 'js'
  end
end
