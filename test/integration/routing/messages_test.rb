# Redmine - project management software
# Copyright (C) 2006-2013  Jean-Philippe Lang
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

class RoutingMessagesTest < ActionController::IntegrationTest
  def test_messages
    assert_routing(
        { :method => 'get', :path => "/boards/22/topics/2" },
        { :controller => 'messages', :action => 'show', :id => '2',
          :board_id => '22' }
      )
    assert_routing(
        { :method => 'get', :path => "/boards/lala/topics/new" },
        { :controller => 'messages', :action => 'new', :board_id => 'lala' }
      )
    assert_routing(
        { :method => 'get', :path => "/boards/lala/topics/22/edit" },
        { :controller => 'messages', :action => 'edit', :id => '22',
          :board_id => 'lala' }
      )
    assert_routing(
        { :method => 'post', :path => "/boards/lala/topics/quote/22" },
        { :controller => 'messages', :action => 'quote', :id => '22',
          :board_id => 'lala' }
      )
    assert_routing(
        { :method => 'post', :path => "/boards/lala/topics/new" },
        { :controller => 'messages', :action => 'new', :board_id => 'lala' }
      )
    assert_routing(
        { :method => 'post', :path => "/boards/lala/topics/preview" },
        { :controller => 'messages', :action => 'preview',
          :board_id => 'lala' }
      )
    assert_routing(
        { :method => 'post', :path => "/boards/lala/topics/22/edit" },
        { :controller => 'messages', :action => 'edit', :id => '22',
          :board_id => 'lala' }
      )
    assert_routing(
        { :method => 'post', :path => "/boards/22/topics/555/replies" },
        { :controller => 'messages', :action => 'reply', :id => '555',
          :board_id => '22' }
      )
    assert_routing(
        { :method => 'post', :path => "/boards/22/topics/555/destroy" },
        { :controller => 'messages', :action => 'destroy', :id => '555',
          :board_id => '22' }
      )
  end
end
