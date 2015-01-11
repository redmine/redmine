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

class RoutingGroupsTest < Redmine::RoutingTest
  def test_groups
    should_route 'GET /groups' => 'groups#index'
    should_route 'GET /groups/new' => 'groups#new'
    should_route 'POST /groups' => 'groups#create'

    should_route 'GET /groups/1' => 'groups#show', :id => '1'
    should_route 'GET /groups/1/edit' => 'groups#edit', :id => '1'
    should_route 'PUT /groups/1' => 'groups#update', :id => '1'
    should_route 'DELETE /groups/1' => 'groups#destroy', :id => '1'

    should_route 'GET /groups/1/autocomplete_for_user' => 'groups#autocomplete_for_user', :id => '1'
    should_route 'GET /groups/1/autocomplete_for_user.js' => 'groups#autocomplete_for_user', :id => '1', :format => 'js'
  end

  def test_group_users
    should_route 'GET /groups/567/users/new' => 'groups#new_users', :id => '567'
    should_route 'POST /groups/567/users' => 'groups#add_users', :id => '567'
    should_route 'DELETE /groups/567/users/12' => 'groups#remove_user', :id => '567', :user_id => '12'
  end
end
