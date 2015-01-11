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

require File.expand_path('../../test_helper', __FILE__)

class MembersControllerTest < ActionController::TestCase
  fixtures :projects, :members, :member_roles, :roles, :users

  def setup
    User.current = nil
    @request.session[:user_id] = 2
  end

  def test_new
    get :new, :project_id => 1
    assert_response :success
  end

  def test_xhr_new
    xhr :get, :new, :project_id => 1
    assert_response :success
    assert_equal 'text/javascript', response.content_type
  end

  def test_create
    assert_difference 'Member.count' do
      post :create, :project_id => 1, :membership => {:role_ids => [1], :user_id => 7}
    end
    assert_redirected_to '/projects/ecookbook/settings/members'
    assert User.find(7).member_of?(Project.find(1))
  end

  def test_create_multiple
    assert_difference 'Member.count', 3 do
      post :create, :project_id => 1, :membership => {:role_ids => [1], :user_ids => [7, 8, 9]}
    end
    assert_redirected_to '/projects/ecookbook/settings/members'
    assert User.find(7).member_of?(Project.find(1))
  end

  def test_xhr_create
    assert_difference 'Member.count', 3 do
      xhr :post, :create, :project_id => 1, :membership => {:role_ids => [1], :user_ids => [7, 8, 9]}
      assert_response :success
      assert_template 'create'
      assert_equal 'text/javascript', response.content_type
    end
    assert User.find(7).member_of?(Project.find(1))
    assert User.find(8).member_of?(Project.find(1))
    assert User.find(9).member_of?(Project.find(1))
    assert_include 'tab-content-members', response.body
  end

  def test_xhr_create_with_failure
    assert_no_difference 'Member.count' do
      xhr :post, :create, :project_id => 1, :membership => {:role_ids => [], :user_ids => [7, 8, 9]}
      assert_response :success
      assert_template 'create'
      assert_equal 'text/javascript', response.content_type
    end
    assert_match /alert/, response.body, "Alert message not sent"
  end

  def test_edit
    assert_no_difference 'Member.count' do
      put :update, :id => 2, :membership => {:role_ids => [1], :user_id => 3}
    end
    assert_redirected_to '/projects/ecookbook/settings/members'
  end

  def test_xhr_edit
    assert_no_difference 'Member.count' do
      xhr :put, :update, :id => 2, :membership => {:role_ids => [1], :user_id => 3}
      assert_response :success
      assert_template 'update'
      assert_equal 'text/javascript', response.content_type
    end
    member = Member.find(2)
    assert_equal [1], member.role_ids
    assert_equal 3, member.user_id
    assert_include 'tab-content-members', response.body
  end

  def test_destroy
    assert_difference 'Member.count', -1 do
      delete :destroy, :id => 2
    end
    assert_redirected_to '/projects/ecookbook/settings/members'
    assert !User.find(3).member_of?(Project.find(1))
  end

  def test_xhr_destroy
    assert_difference 'Member.count', -1 do
      xhr :delete, :destroy, :id => 2
      assert_response :success
      assert_template 'destroy'
      assert_equal 'text/javascript', response.content_type
    end
    assert_nil Member.find_by_id(2)
    assert_include 'tab-content-members', response.body
  end

  def test_autocomplete
    xhr :get, :autocomplete, :project_id => 1, :q => 'mis', :format => 'js'
    assert_response :success
    assert_include 'User Misc', response.body
  end
end
