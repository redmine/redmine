# redMine - project management software
# Copyright (C) 2008  FreeCode
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

require File.dirname(__FILE__) + '/../test_helper'
require 'groups_controller'

# Re-raise errors caught by the controller.
class GroupsController; def rescue_action(e) raise e end; end

class GroupsControllerTest < Test::Unit::TestCase
  fixtures :groups, :users
  
  def setup
    @controller = GroupsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    User.current = nil
    @request.session[:user_id] = 1 # admin
  end
  
  def test_should_get_index
    get :index
    assert_response :success
    assert_not_nil assigns(:groups)
  end

  def test_should_get_new
    get :new
    assert_response :success
  end

  def test_should_create_group
    assert_difference('Group.count') do
      post :create, :group => { :name => 'New group' }
    end
    assert_redirected_to groups_path
    assert_not_nil Group.find_by_name('New group')
  end

  def test_should_show_group
    get :show, :id => 1
    assert_response :success
  end

  def test_should_get_edit
    get :edit, :id => 1
    assert_response :success
  end

  def test_should_update_group
    put :update, :id => 1, :group => { :name => 'Renamed' }
    assert_redirected_to groups_path
    assert_equal 'Renamed', Group.find(1).name
  end

  def test_should_destroy_group
    assert_difference('Group.count', -1) do
      delete :destroy, :id => 1
    end
    assert_redirected_to groups_path
  end
end
