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

class RoutingTrackersTest < Redmine::RoutingTest
  def test_trackers
    should_route 'GET /trackers' => 'trackers#index'
    should_route 'GET /trackers/new' => 'trackers#new'
    should_route 'POST /trackers' => 'trackers#create'

    should_route 'GET /trackers/1/edit' => 'trackers#edit', :id => '1'
    should_route 'PUT /trackers/1' => 'trackers#update', :id => '1'
    should_route 'DELETE /trackers/1' => 'trackers#destroy', :id => '1'

    should_route 'GET /trackers/fields' => 'trackers#fields'
    should_route 'POST /trackers/fields' => 'trackers#fields'
  end
end
