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

class RolesControllerTest < ActionController::TestCase
  fixtures :roles, :users, :members, :member_roles, :workflows, :trackers

  def setup
    User.current = nil
    @request.session[:user_id] = 1 # admin
  end

  def test_index
    get :index
    assert_response :success
    assert_template 'index'

    assert_not_nil assigns(:roles)
    assert_equal Role.order('builtin, position').to_a, assigns(:roles)

    assert_select 'a[href="/roles/1/edit"]', :text => 'Manager'
  end

  def test_new
    get :new
    assert_response :success
    assert_template 'new'
  end

  def test_new_with_copy
    copy_from = Role.find(2)

    get :new, :copy => copy_from.id.to_s
    assert_response :success
    assert_template 'new'

    role = assigns(:role)
    assert_equal copy_from.permissions, role.permissions

    assert_select 'form' do
      # blank name
      assert_select 'input[name=?][value=""]', 'role[name]'
      # edit_project permission checked
      assert_select 'input[type=checkbox][name=?][value=edit_project][checked=checked]', 'role[permissions][]'
      # add_project permission not checked
      assert_select 'input[type=checkbox][name=?][value=add_project]', 'role[permissions][]'
      assert_select 'input[type=checkbox][name=?][value=add_project][checked=checked]', 'role[permissions][]', 0
      # workflow copy selected
      assert_select 'select[name=?]', 'copy_workflow_from' do
        assert_select 'option[value="2"][selected=selected]'
      end
    end
  end

  def test_create_with_validaton_failure
    post :create, :role => {:name => '',
                         :permissions => ['add_issues', 'edit_issues', 'log_time', ''],
                         :assignable => '0'}

    assert_response :success
    assert_template 'new'
    assert_select 'div#errorExplanation'
  end

  def test_create_without_workflow_copy
    post :create, :role => {:name => 'RoleWithoutWorkflowCopy',
                         :permissions => ['add_issues', 'edit_issues', 'log_time', ''],
                         :assignable => '0'}

    assert_redirected_to '/roles'
    role = Role.find_by_name('RoleWithoutWorkflowCopy')
    assert_not_nil role
    assert_equal [:add_issues, :edit_issues, :log_time], role.permissions
    assert !role.assignable?
  end

  def test_create_with_workflow_copy
    post :create, :role => {:name => 'RoleWithWorkflowCopy',
                         :permissions => ['add_issues', 'edit_issues', 'log_time', ''],
                         :assignable => '0'},
               :copy_workflow_from => '1'

    assert_redirected_to '/roles'
    role = Role.find_by_name('RoleWithWorkflowCopy')
    assert_not_nil role
    assert_equal Role.find(1).workflow_rules.size, role.workflow_rules.size
  end

  def test_edit
    get :edit, :id => 1
    assert_response :success
    assert_template 'edit'
    assert_equal Role.find(1), assigns(:role)
    assert_select 'select[name=?]', 'role[issues_visibility]'
  end

  def test_edit_anonymous
    get :edit, :id => Role.anonymous.id
    assert_response :success
    assert_template 'edit'
    assert_select 'select[name=?]', 'role[issues_visibility]', 0
  end

  def test_edit_invalid_should_respond_with_404
    get :edit, :id => 999
    assert_response 404
  end

  def test_update
    put :update, :id => 1,
                :role => {:name => 'Manager',
                          :permissions => ['edit_project', ''],
                          :assignable => '0'}

    assert_redirected_to '/roles'
    role = Role.find(1)
    assert_equal [:edit_project], role.permissions
  end

  def test_update_trackers_permissions
    put :update, :id => 1, :role => {
      :permissions_all_trackers => {'add_issues' => '0'},
      :permissions_tracker_ids => {'add_issues' => ['1', '3', '']}
    }

    assert_redirected_to '/roles'
    role = Role.find(1)

    assert_equal({'add_issues' => '0'}, role.permissions_all_trackers)
    assert_equal({'add_issues' => ['1', '3']}, role.permissions_tracker_ids)

    assert_equal false, role.permissions_all_trackers?(:add_issues)
    assert_equal [1, 3], role.permissions_tracker_ids(:add_issues).sort
  end

  def test_update_with_failure
    put :update, :id => 1, :role => {:name => ''}
    assert_response :success
    assert_template 'edit'
  end

  def test_destroy
    r = Role.create!(:name => 'ToBeDestroyed', :permissions => [:view_wiki_pages])

    delete :destroy, :id => r
    assert_redirected_to '/roles'
    assert_nil Role.find_by_id(r.id)
  end

  def test_destroy_role_in_use
    delete :destroy, :id => 1
    assert_redirected_to '/roles'
    assert_equal 'This role is in use and cannot be deleted.', flash[:error] 
    assert_not_nil Role.find_by_id(1)
  end

  def test_get_permissions
    get :permissions
    assert_response :success
    assert_template 'permissions'

    assert_not_nil assigns(:roles)
    assert_equal Role.order('builtin, position').to_a, assigns(:roles)

    assert_select 'input[name=?][type=checkbox][value=add_issues][checked=checked]', 'permissions[3][]'
    assert_select 'input[name=?][type=checkbox][value=delete_issues]:not([checked])', 'permissions[3][]'
  end

  def test_post_permissions
    post :permissions, :permissions => { '0' => '', '1' => ['edit_issues'], '3' => ['add_issues', 'delete_issues']}
    assert_redirected_to '/roles'

    assert_equal [:edit_issues], Role.find(1).permissions
    assert_equal [:add_issues, :delete_issues], Role.find(3).permissions
    assert Role.find(2).permissions.empty?
  end

  def test_clear_all_permissions
    post :permissions, :permissions => { '0' => '' }
    assert_redirected_to '/roles'
    assert Role.find(1).permissions.empty?
  end

  def test_move_highest
    put :update, :id => 3, :role => {:position => 1}
    assert_redirected_to '/roles'
    assert_equal 1, Role.find(3).position
  end

  def test_move_higher
    position = Role.find(3).position
    put :update, :id => 3, :role => {:position => position - 1}
    assert_redirected_to '/roles'
    assert_equal position - 1, Role.find(3).position
  end

  def test_move_lower
    position = Role.find(2).position
    put :update, :id => 2, :role => {:position => position + 1}
    assert_redirected_to '/roles'
    assert_equal position + 1, Role.find(2).position
  end

  def test_move_lowest
    put :update, :id => 2, :role => {:position => Role.givable.count}
    assert_redirected_to '/roles'
    assert_equal Role.givable.count, Role.find(2).position
  end
end
