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

class RoutingUsersTest < Redmine::RoutingTest
  def test_users
    should_route 'GET /users' => 'users#index'
    should_route 'GET /users/new' => 'users#new'
    should_route 'POST /users' => 'users#create'

    should_route 'GET /users/44' => 'users#show', :id => '44'
    should_route 'GET /users/current' => 'users#show', :id => 'current'
    should_route 'GET /users/44/edit' => 'users#edit', :id => '44'
    should_route 'PUT /users/44' => 'users#update', :id => '44'
    should_route 'DELETE /users/44' => 'users#destroy', :id => '44'

    should_route  'DELETE /users/bulk_destroy' => 'users#bulk_destroy'
    should_route  'POST /users/bulk_lock' => 'users#bulk_lock'
    should_route  'POST /users/bulk_unlock' => 'users#bulk_unlock'
  end
end
