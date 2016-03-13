# Redmine - project management software
# Copyright (C) 2006-2016  Jean-Philippe Lang
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

require File.expand_path('../../test_helper', __FILE__)

class GroupsControllerTest < ActionController::TestCase
  fixtures :projects, :users, :members, :member_roles, :roles, :groups_users

  def setup
    @request.session[:user_id] = 1
  end

  def test_index
    get :index
    assert_response :success
    assert_template 'index'
  end

  def test_index_should_show_user_count
    get :index
    assert_response :success
    assert_select 'tr#group-11 td.user_count', :text => '1'
  end

  def test_show
    get :show, :id => 10
    assert_response :success
    assert_template 'show'
  end

  def test_show_invalid_should_return_404
    get :show, :id => 99
    assert_response 404
  end

  def test_new
    get :new
    assert_response :success
    assert_template 'new'
    assert_select 'input[name=?]', 'group[name]'
  end

  def test_create
    assert_difference 'Group.count' do
      post :create, :group => {:name => 'New group'}
    end
    assert_redirected_to '/groups'
    group = Group.order('id DESC').first
    assert_equal 'New group', group.name
    assert_equal [], group.users
  end

  def test_create_and_continue
    assert_difference 'Group.count' do
      post :create, :group => {:name => 'New group'}, :continue => 'Create and continue'
    end
    assert_redirected_to '/groups/new'
    group = Group.order('id DESC').first
    assert_equal 'New group', group.name
  end

  def test_create_with_failure
    assert_no_difference 'Group.count' do
      post :create, :group => {:name => ''}
    end
    assert_response :success
    assert_template 'new'
  end

  def test_edit
    get :edit, :id => 10
    assert_response :success
    assert_template 'edit'

    assert_select 'div#tab-content-users'
    assert_select 'div#tab-content-memberships' do
      assert_select 'a', :text => 'Private child of eCookbook'
    end
  end

  def test_update
    new_name = 'New name'
    put :update, :id => 10, :group => {:name => new_name}
    assert_redirected_to '/groups'
    group = Group.find(10)
    assert_equal new_name, group.name
  end

  def test_update_with_failure
    put :update, :id => 10, :group => {:name => ''}
    assert_response :success
    assert_template 'edit'
  end

  def test_destroy
    assert_difference 'Group.count', -1 do
      post :destroy, :id => 10
    end
    assert_redirected_to '/groups'
  end

  def test_new_users
    get :new_users, :id => 10
    assert_response :success
    assert_template 'new_users'
  end

  def test_xhr_new_users
    xhr :get, :new_users, :id => 10
    assert_response :success
    assert_equal 'text/javascript', response.content_type
  end

  def test_add_users
    assert_difference 'Group.find(10).users.count', 2 do
      post :add_users, :id => 10, :user_ids => ['2', '3']
    end
  end

  def test_xhr_add_users
    assert_difference 'Group.find(10).users.count', 2 do
      xhr :post, :add_users, :id => 10, :user_ids => ['2', '3']
      assert_response :success
      assert_template 'add_users'
      assert_equal 'text/javascript', response.content_type
    end
    assert_match /John Smith/, response.body
  end

  def test_remove_user
    assert_difference 'Group.find(10).users.count', -1 do
      delete :remove_user, :id => 10, :user_id => '8'
    end
  end

  def test_xhr_remove_user
    assert_difference 'Group.find(10).users.count', -1 do
      xhr :delete, :remove_user, :id => 10, :user_id => '8'
      assert_response :success
      assert_template 'remove_user'
      assert_equal 'text/javascript', response.content_type
    end
  end

  def test_autocomplete_for_user
    xhr :get, :autocomplete_for_user, :id => 10, :q => 'smi', :format => 'js'
    assert_response :success
    assert_include 'John Smith', response.body
  end
end
