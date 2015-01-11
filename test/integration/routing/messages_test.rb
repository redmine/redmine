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

class RoutingMessagesTest < Redmine::RoutingTest
  def test_messages
    # TODO: refactor routes
    should_route 'GET /boards/22/topics/new' => 'messages#new', :board_id => '22'
    should_route 'POST /boards/22/topics/new' => 'messages#new', :board_id => '22'
    should_route 'POST /boards/22/topics/preview' => 'messages#preview', :board_id => '22'

    should_route 'GET /boards/22/topics/2' => 'messages#show', :id => '2', :board_id => '22'
    should_route 'GET /boards/22/topics/2/edit' => 'messages#edit', :id => '2', :board_id => '22'
    should_route 'POST /boards/22/topics/quote/2' => 'messages#quote', :id => '2', :board_id => '22'
    should_route 'POST /boards/22/topics/2/replies' => 'messages#reply', :id => '2', :board_id => '22'
    should_route 'POST /boards/22/topics/2/destroy' => 'messages#destroy', :id => '2', :board_id => '22'
  end
end
