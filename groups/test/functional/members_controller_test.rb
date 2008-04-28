# Redmine - project management software
# Copyright (C) 2008  Jean-Philippe Lang
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
require 'members_controller'

# Re-raise errors caught by the controller.
class MembersController; def rescue_action(e) raise e end; end

class MembersControllerTest < Test::Unit::TestCase
  fixtures :projects, :roles, :users, :groups, :members
  
  def setup
    @controller = MembersController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    User.current = nil
    @request.session[:user_id] = 1 # admin
  end
  
  def test_should_create_user_member
    p = Project.find(1)
    u = users(:new_client)
    assert_difference('Member.count') do
      post :new, :id => p.id, :member => { :role_id => roles(:reporter).id }, :principal => "user_#{u.id}"
    end
    assert_redirected_to :controller => 'projects', :action => 'settings', :id => p, :tab => 'members'
    assert u.reload.member_of?(p)
    assert_equal roles(:reporter), u.role_for_project(p)
  end
  
  def test_should_create_group_member
    p = Project.find(2)
    assert_difference('Member.count') do
      post :new, :id => p.id, :member => { :role_id => roles(:reporter) }, :principal => 'group_1'
    end
    assert_redirected_to :controller => 'projects', :action => 'settings', :id => p, :tab => 'members'
  end
  
  def test_should_update_user_member
    u = User.find(3)
    p = Project.find(1)
    assert_equal roles(:developer), u.role_for_project(p)
    assert_difference('Member.count', 0) do
      post :edit, :id => 2, :member => { :role_id => roles(:manager).id }
    end
    assert_redirected_to :controller => 'projects', :action => 'settings', :id => p, :tab => 'members'
    assert_equal roles(:manager), u.reload.role_for_project(p)
  end
  
  def test_should_destroy
    p = Project.find(1)
    assert_difference('Member.count', -1) do
      post :destroy, :id => 2
    end
    assert_redirected_to :controller => 'projects', :action => 'settings', :id => p, :tab => 'members'
  end
  
  def test_should_not_destroy_inherited_membership
    p = Project.find(1)
    assert_difference('Member.count', 0) do
      post :destroy, :id => 6
    end
    assert_response 404
  end
end
