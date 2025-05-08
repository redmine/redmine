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

class RoutingMyTest < Redmine::RoutingTest
  def test_my
    should_route 'GET /my/account' => 'my#account'
    should_route 'PUT /my/account' => 'my#account'

    should_route 'GET /my/account/destroy' => 'my#destroy'
    should_route 'POST /my/account/destroy' => 'my#destroy'

    should_route 'GET /my/page' => 'my#page'
    should_route 'POST /my/page' => 'my#update_page'
    should_route 'GET /my' => 'my#index'

    should_route 'GET /my/api_key' => 'my#show_api_key'
    should_route 'POST /my/api_key' => 'my#reset_api_key'
    should_route 'POST /my/atom_key' => 'my#reset_atom_key'

    should_route 'GET /my/password' => 'my#password'
    should_route 'POST /my/password' => 'my#password'

    should_route 'POST /my/add_block' => 'my#add_block'
    should_route 'POST /my/remove_block' => 'my#remove_block'
    should_route 'POST /my/order_blocks' => 'my#order_blocks'
  end
end
