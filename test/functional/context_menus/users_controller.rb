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

module ContextMenus
  class UsersControllerTest < Redmine::ControllerTest
    def test_users_context_menu
      @request.session[:user_id] = 1 # admin
      get :index, :params => {:ids => [8]}
      assert_response :success

      assert_select 'li.folder' do
        assert_select 'a', :text => 'Add to group'
        assert_select 'ul' do
          assert_select 'a', :text => 'A Team'
        end
      end
      # User 8 is in Group 10
      assert_select 'li.folder' do
        assert_select 'a', :text => 'Remove from group'
        assert_select 'a', :text => 'A Team'
      end
    end

    def test_users_context_menu_bulk
      @request.session[:user_id] = 1 # admin
      # Add user 2 to group 10 (user 8 is already there)
      Group.find(10).users << User.find(2)

      get :index, :params => {:ids => [2, 8]}
      assert_response :success

      assert_select 'li.folder' do
        assert_select 'a', :text => 'Add to group'
        assert_select 'ul' do
          assert_select 'a', :text => 'A Team'
          assert_select 'a', :text => 'B Team'
        end
      end
      # Both users are in Group 10
      assert_select 'li.folder' do
        assert_select 'a', :text => 'Remove from group'
        assert_select 'a', :text => 'A Team'
      end
    end

    def test_users_context_menu_bulk_with_different_groups
      @request.session[:user_id] = 1 # admin
      # User 8 is in Group 10
      # Add User 2 to Group 11
      Group.find(11).users << User.find(2)

      get :index, :params => {:ids => [2, 8]}
      assert_response :success

      # Both Group 10 and Group 11 should be in the Remove submenu
      assert_select 'li.folder' do
        assert_select 'a', :text => 'Remove from group'
        assert_select 'ul' do
          assert_select 'a', :text => 'A Team'
          assert_select 'a', :text => 'B Team'
        end
      end
    end

    def test_users_context_menu_without_permission
      @request.session[:user_id] = 2

      get :index, :params => {:ids => [8]}
      assert_response :forbidden
    end
  end
end
