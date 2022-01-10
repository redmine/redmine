# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2022  Jean-Philippe Lang
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

class RoutingPrincipalMembershipsTest < Redmine::RoutingTest
  def test_user_memberships
    should_route 'GET /users/123/memberships/new' => 'principal_memberships#new', :user_id => '123'
    should_route 'POST /users/123/memberships' => 'principal_memberships#create', :user_id => '123'
    should_route 'GET /users/123/memberships/55/edit' => 'principal_memberships#edit', :user_id => '123', :id => '55'
    should_route 'PUT /users/123/memberships/55' => 'principal_memberships#update', :user_id => '123', :id => '55'
    should_route 'DELETE /users/123/memberships/55' => 'principal_memberships#destroy', :user_id => '123', :id => '55'
  end

  def test_group_memberships
    should_route 'GET /groups/123/memberships/new' => 'principal_memberships#new', :group_id => '123'
    should_route 'POST /groups/123/memberships' => 'principal_memberships#create', :group_id => '123'
    should_route 'GET /groups/123/memberships/55/edit' => 'principal_memberships#edit', :group_id => '123', :id => '55'
    should_route 'PUT /groups/123/memberships/55' => 'principal_memberships#update', :group_id => '123', :id => '55'
    should_route 'DELETE /groups/123/memberships/55' => 'principal_memberships#destroy', :group_id => '123', :id => '55'
  end
end
