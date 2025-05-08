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

class RoutingRolesTest < Redmine::RoutingTest
  def test_roles
    should_route 'GET /roles' => 'roles#index'
    should_route 'GET /roles/new' => 'roles#new'
    should_route 'POST /roles' => 'roles#create'

    should_route 'GET /roles/2/edit' => 'roles#edit', :id => '2'
    should_route 'PUT /roles/2' => 'roles#update', :id => '2'
    should_route 'DELETE /roles/2' => 'roles#destroy', :id => '2'

    should_route 'GET /roles/permissions' => 'roles#permissions'
    should_route 'POST /roles/permissions' => 'roles#update_permissions'
  end
end
