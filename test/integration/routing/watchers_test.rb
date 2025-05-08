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

class RoutingWatchersTest < Redmine::RoutingTest
  def test_watchers
    should_route 'GET /watchers/new' => 'watchers#new'
    should_route 'POST /watchers/append' => 'watchers#append'
    should_route 'POST /watchers' => 'watchers#create'
    should_route 'DELETE /watchers' => 'watchers#destroy'
    should_route 'GET /watchers/autocomplete_for_user' => 'watchers#autocomplete_for_user'

    should_route 'POST /watchers/watch' => 'watchers#watch'
    should_route 'DELETE /watchers/watch' => 'watchers#unwatch'
  end
end
