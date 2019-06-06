# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2019  Jean-Philippe Lang
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

class PrincipalMembershipsControllerTest < Redmine::ControllerTest
  fixtures :projects, :users, :members, :member_roles, :roles, :groups_users

  def setup
    @request.session[:user_id] = 1
  end

  def test_new_user_membership
    get :new, :params => {
        :user_id => 7
      }
    assert_response :success
    assert_select 'label', :text => 'eCookbook' do
      assert_select 'input[name=?][value="1"]:not([disabled])', 'membership[project_ids][]'
    end
  end

  def test_new_user_membership_should_disable_user_projects
    Member.create!(:user_id => 7, :project_id => 1, :role_ids => [1])

    get :new, :params => {
        :user_id => 7
      }
    assert_response :success
    assert_select 'label', :text => 'eCookbook' do
      assert_select 'input[name=?][value="1"][disabled=disabled]', 'membership[project_ids][]'
    end
  end

  def test_xhr_new_user_membership
    get :new, :params => {
        :user_id => 7
      },
      :xhr => true
    assert_response :success
    assert_equal 'text/javascript', response.content_type
  end

  def test_create_user_membership
    assert_difference 'Member.count' do
      post :create, :params => {
          :user_id => 7,
          :membership => {
            :project_ids => [3],
            :role_ids => [2]
          }
        }
    end
    assert_redirected_to '/users/7/edit?tab=memberships'
    member = Member.order('id DESC').first
    assert_equal User.find(7), member.principal
    assert_equal [2], member.role_ids
    assert_equal 3, member.project_id
  end

  def test_create_user_membership_with_multiple_roles
    assert_difference 'Member.count' do
      post :create, :params => {
          :user_id => 7,
          :membership => {
            :project_ids => [3],
            :role_ids => [2, 3]
          }
        }
    end
    member = Member.order('id DESC').first
    assert_equal User.find(7), member.principal
    assert_equal [2, 3], member.role_ids.sort
    assert_equal 3, member.project_id
  end

  def test_create_user_membership_with_multiple_projects_and_roles
    assert_difference 'Member.count', 2 do
      post :create, :params => {
          :user_id => 7,
          :membership => {
            :project_ids => [1, 3],
            :role_ids => [2, 3]
          }
        }
    end
    members = Member.order('id DESC').limit(2).sort_by(&:project_id)
    assert_equal 1, members[0].project_id
    assert_equal 3, members[1].project_id
    members.each do |member|
      assert_equal User.find(7), member.principal
      assert_equal [2, 3], member.role_ids.sort
    end
  end

  def test_xhr_create_user_membership
    assert_difference 'Member.count' do
      post :create, :params => {
          :user_id => 7,
          :membership => {
            :project_ids => [3],
            :role_ids => [2]
          },
          :format => 'js'
        },
        :xhr => true
      assert_response :success
      assert_equal 'text/javascript', response.content_type
    end
    member = Member.order('id DESC').first
    assert_equal User.find(7), member.principal
    assert_equal [2], member.role_ids
    assert_equal 3, member.project_id
    assert_include 'tab-content-memberships', response.body
  end

  def test_xhr_create_user_membership_with_failure
    assert_no_difference 'Member.count' do
      post :create, :params => {
          :user_id => 7,
          :membership => {
            :project_ids => [3]
          },
          :format => 'js'
        },
        :xhr => true
      assert_response :success
      assert_equal 'text/javascript', response.content_type
    end
    assert_include 'alert', response.body, "Alert message not sent"
    assert_include 'Role cannot be empty', response.body, "Error message not sent"
  end

  def test_edit_user_membership
    get :edit, :params => {
        :user_id => 2,
        :id => 1
      }
    assert_response :success
    assert_select 'input[name=?][value=?][checked=checked]', 'membership[role_ids][]', '1'
  end

  def test_xhr_edit_user_membership
    get :edit, :params => {
        :user_id => 2,
        :id => 1
      },
      :xhr => true
    assert_response :success
  end

  def test_update_user_membership
    assert_no_difference 'Member.count' do
      put :update, :params => {
          :user_id => 2,
          :id => 1,
          :membership => {
            :role_ids => [2]
          }
        }
      assert_redirected_to '/users/2/edit?tab=memberships'
    end
    assert_equal [2], Member.find(1).role_ids
  end

  def test_xhr_update_user_membership
    assert_no_difference 'Member.count' do
      put :update, :params => {
          :user_id => 2,
          :id => 1,
          :membership => {
            :role_ids => [2]
          },
          :format => 'js'
        },
        :xhr => true
      assert_response :success
      assert_equal 'text/javascript', response.content_type
    end
    assert_equal [2], Member.find(1).role_ids
    assert_include '$("#member-1-roles").html("Developer").show();', response.body
  end

  def test_destroy_user_membership
    assert_difference 'Member.count', -1 do
      delete :destroy, :params => {
          :user_id => 2,
          :id => 1
        }
    end
    assert_redirected_to '/users/2/edit?tab=memberships'
    assert_nil Member.find_by_id(1)
  end

  def test_xhr_destroy_user_membership_js_format
    assert_difference 'Member.count', -1 do
      delete :destroy, :params => {
          :user_id => 2,
          :id => 1
        },
        :xhr => true
      assert_response :success
      assert_equal 'text/javascript', response.content_type
    end
    assert_nil Member.find_by_id(1)
    assert_include 'tab-content-memberships', response.body
  end

  def test_xhr_new_group_membership
    get :new, :params => {
        :group_id => 10
      },
      :xhr => true
    assert_response :success
    assert_equal 'text/javascript', response.content_type
  end

  def test_create_group_membership
    assert_difference 'Group.find(10).members.count' do
      post :create, :params => {
          :group_id => 10,
          :membership => {
            :project_ids => [2],
            :role_ids => ['1', '2']
          }
        }
    end
  end

  def test_xhr_create_group_membership
    assert_difference 'Group.find(10).members.count' do
      post :create, :params => {
          :group_id => 10,
          :membership => {
            :project_ids => [2],
            :role_ids => ['1', '2']
          }
        },
        :xhr => true
      assert_response :success
      assert_equal 'text/javascript', response.content_type
    end
    assert_match /OnlineStore/, response.body
  end

  def test_xhr_create_group_membership_with_failure
    assert_no_difference 'Group.find(10).members.count' do
      post :create, :params => {
          :group_id => 10,
          :membership => {
            :project_ids => [999],
            :role_ids => ['1', '2']
          }
        },
        :xhr => true
      assert_response :success
      assert_equal 'text/javascript', response.content_type
    end
    assert_match /alert/, response.body, "Alert message not sent"
  end

  def test_update_group_membership
    assert_no_difference 'Group.find(10).members.count' do
      put :update, :params => {
          :group_id => 10,
          :id => 6,
          :membership => {
            :role_ids => ['1', '3']
          }
        }
    end
  end

  def test_xhr_update_group_membership
    assert_no_difference 'Group.find(10).members.count' do
      post :update, :params => {
          :group_id => 10,
          :id => 6,
          :membership => {
            :role_ids => ['1', '3']
          }
        },
        :xhr => true
      assert_response :success
      assert_equal 'text/javascript', response.content_type
    end
  end

  def test_destroy_group_membership
    assert_difference 'Group.find(10).members.count', -1 do
      delete :destroy, :params => {
          :group_id => 10,
          :id => 6
        }
    end
  end

  def test_xhr_destroy_group_membership
    assert_difference 'Group.find(10).members.count', -1 do
      delete :destroy, :params => {
          :group_id => 10,
          :id => 6
        },
        :xhr => true
      assert_response :success
      assert_equal 'text/javascript', response.content_type
    end
  end
end
