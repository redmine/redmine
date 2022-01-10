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

class RoutingAuthSourcesTest < Redmine::RoutingTest
  def test_auth_sources
    should_route 'GET /auth_sources' => 'auth_sources#index'
    should_route 'GET /auth_sources/new' => 'auth_sources#new'
    should_route 'POST /auth_sources' => 'auth_sources#create'
    should_route 'GET /auth_sources/autocomplete_for_new_user' => 'auth_sources#autocomplete_for_new_user'

    should_route 'GET /auth_sources/1234/edit' => 'auth_sources#edit', :id => '1234'
    should_route 'PUT /auth_sources/1234' => 'auth_sources#update', :id => '1234'
    should_route 'DELETE /auth_sources/1234' => 'auth_sources#destroy', :id => '1234'
    should_route 'GET /auth_sources/1234/test_connection' => 'auth_sources#test_connection', :id => '1234'
  end
end
