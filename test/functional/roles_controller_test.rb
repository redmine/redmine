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

require_relative '../test_helper'

class RolesControllerTest < Redmine::ControllerTest
  def setup
    User.current = nil
    @request.session[:user_id] = 1 # admin
  end

  def test_index
    get :index
    assert_response :success

    assert_select 'table.roles tbody' do
      assert_select 'tr', Role.count
      assert_select 'a[href="/roles/1/edit"]', :text => 'Manager'
    end
  end

  def test_index_should_show_warning_when_no_workflow_is_defined
    Role.find_by_name('Developer').workflow_rules.destroy_all
    Role.find_by_name('Anonymous').workflow_rules.destroy_all

    get :index
    assert_response :success
    assert_select 'table.roles' do
      # Manager
      assert_select 'tr.givable:nth-of-type(1) span.icon-warning', :count => 0
      # Developer
      assert_select 'tr.givable:nth-of-type(2) span.icon-warning', :text => /#{I18n.t(:text_role_no_workflow)}/
      # Reporter
      assert_select 'tr.givable:nth-of-type(3) span.icon-warning', :count => 0
      # No warnings for built-in roles such as Anonymous and Non-member
      assert_select 'tr.builtin span.icon-warning', :count => 0
    end
  end

  def test_new
    get :new
    assert_response :success
    assert_select 'input[name=?]', 'role[name]'
    assert_select 'input[name=?]', 'role[permissions][]'
  end

  def test_new_should_prefill_permissions_with_non_member_permissions
    role = Role.non_member
    role.permissions = [:view_issues, :view_documents]
    role.save!

    get :new
    assert_response :success
    assert_equal(
      %w(view_documents view_issues),
      css_select('input[name="role[permissions][]"][checked=checked]').map {|e| e.attr(:value)}.sort
    )
  end

  def test_new_with_copy
    copy_from = Role.find(2)

    get :new, :params => {:copy => copy_from.id.to_s}
    assert_response :success
    assert_select 'input[name=?]', 'role[name]'

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
    post(
      :create,
      :params => {
        :role => {
          :name => '',
          :permissions => ['add_issues', 'edit_issues', 'log_time', ''],
          :assignable => '0'
        }
      }
    )
    assert_response :success
    assert_select_error /Name cannot be blank/
  end

  def test_create_without_workflow_copy
    post(
      :create,
      :params => {
        :role => {
          :name => 'RoleWithoutWorkflowCopy',
          :permissions => ['add_issues', 'edit_issues', 'log_time', ''],
          :assignable => '0'
        }
      }
    )
    assert_redirected_to '/roles'
    role = Role.find_by_name('RoleWithoutWorkflowCopy')
    assert_not_nil role
    assert_equal [:add_issues, :edit_issues, :log_time], role.permissions
    assert !role.assignable?
  end

  def test_create_with_workflow_copy
    post(
      :create,
      :params => {
        :role => {
          :name => 'RoleWithWorkflowCopy',
          :permissions => ['add_issues', 'edit_issues', 'log_time', ''],
          :assignable => '0'
        },
        :copy_workflow_from => '1'
      }
    )
    assert_redirected_to '/roles'
    role = Role.find_by_name('RoleWithWorkflowCopy')
    assert_not_nil role
    assert_equal Role.find(1).workflow_rules.size, role.workflow_rules.size
  end

  def test_create_with_managed_roles
    role = new_record(Role) do
      post(
        :create,
        :params => {
          :role => {
            :name => 'Role',
            :all_roles_managed => '0',
            :managed_role_ids => ['2', '3', '']
          }
        }
      )
      assert_response :found
    end
    assert_equal false, role.all_roles_managed
    assert_equal [2, 3], role.managed_role_ids.sort
  end

  def test_edit
    get :edit, :params => {:id => 1}
    assert_response :success

    assert_select 'input[name=?][value=?]', 'role[name]', 'Manager'
    assert_select 'select[name=?]', 'role[issues_visibility]'
    assert_select '#role-permissions-trackers table .delete_issues_shown'
  end

  def test_edit_anonymous
    get :edit, :params => {:id => Role.anonymous.id}
    assert_response :success

    assert_select 'input[name=?]', 'role[name]', 0
    assert_select 'select[name=?]', 'role[issues_visibility]', 0
    assert_select '#role-permissions-trackers table .delete_issues_shown', 0
  end

  def test_edit_invalid_should_respond_with_404
    get :edit, :params => {:id => 999}
    assert_response :not_found
  end

  def test_update
    put(
      :update,
      :params => {
        :id => 1,
        :role => {
          :name => 'Manager',
          :permissions => ['edit_project', ''],
          :assignable => '0'
        }
      }
    )
    assert_redirected_to '/roles'
    role = Role.find(1)
    assert_equal [:edit_project], role.permissions
  end

  def test_update_trackers_permissions
    put(
      :update,
      :params => {
        :id => 1,
        :role => {
          :permissions_all_trackers => {'add_issues' => '0'},
          :permissions_tracker_ids => {'add_issues' => ['1', '3', '']}
        }
      }
    )
    assert_redirected_to '/roles'
    role = Role.find(1)

    assert_equal({'add_issues' => '0'}, role.permissions_all_trackers)
    assert_equal({'add_issues' => ['1', '3']}, role.permissions_tracker_ids)

    assert_equal false, role.permissions_all_trackers?(:add_issues)
    assert_equal [1, 3], role.permissions_tracker_ids(:add_issues).sort
  end

  def test_update_with_failure
    put :update, :params => {:id => 1, :role => {:name => ''}}
    assert_response :success
    assert_select_error /Name cannot be blank/
  end

  def test_destroy
    r = Role.create!(:name => 'ToBeDestroyed', :permissions => [:view_wiki_pages])

    delete :destroy, :params => {:id => r}
    assert_redirected_to '/roles'
    assert_nil Role.find_by_id(r.id)
  end

  def test_destroy_role_in_use
    delete :destroy, :params => {:id => 1}
    assert_redirected_to '/roles'
    assert_equal 'This role is in use and cannot be deleted.', flash[:error]
    assert_not_nil Role.find_by_id(1)
  end

  def test_permissions
    get :permissions
    assert_response :success

    assert_select 'input[name=?][type=checkbox][value=add_issues][checked=checked]', 'permissions[3][]'
    assert_select 'input[name=?][type=checkbox][value=delete_issues]:not([checked])', 'permissions[3][]'
  end

  def test_permissions_with_filter
    get(
      :permissions,
      :params => {
        :ids => ['2', '3']
      }
    )
    assert_response :success

    assert_select 'table.permissions thead th', 3
    assert_select 'input[name=?][type=checkbox][value=add_issues][checked=checked]', 'permissions[3][]'
    assert_select 'input[name=?][type=checkbox][value=delete_issues]:not([checked])', 'permissions[3][]'
  end

  def test_permissions_csv_export
    get(
      :permissions,
      :params => {
        :format => 'csv'
      }
    )
    assert_response :success

    assert_equal 'text/csv; header=present', @response.media_type
    lines = @response.body.chomp.split("\n")
    # Number of lines
    permissions = Redmine::AccessControl.permissions - Redmine::AccessControl.public_permissions
    permissions = permissions.group_by{|p| p.project_module.to_s}.sort.collect(&:last).flatten
    assert_equal permissions.size + 1, lines.size
    # Header
    assert_equal 'Module,Permissions,Manager,Developer,Reporter,Non member,Anonymous', lines.first
    # Details
    to_test = {
      :add_project => '"",Create project,Yes,No,No,No,""',
      :add_issue_notes => 'Issue tracking,Add notes,Yes,Yes,Yes,Yes,Yes',
      :manage_wiki => 'Wiki,Manage wiki,Yes,No,No,"",""'
    }
    to_test.each do |name, expected|
      index = permissions.find_index {|p| p.name == name}
      assert_not_nil index
      assert_equal expected, lines[index + 1]
    end
  end

  def test_update_permissions
    post(
      :update_permissions,
      :params => {
        :permissions => {
          '1' => ['edit_issues'],
          '3' => ['add_issues', 'delete_issues']
        }
      }
    )
    assert_redirected_to '/roles'

    assert_equal [:edit_issues], Role.find(1).permissions
    assert_equal [:add_issues, :delete_issues], Role.find(3).permissions
  end

  def test_update_permissions_should_not_update_other_roles
    assert_no_changes lambda {Role.find(2).permissions} do
      assert_changes lambda {Role.find(1).permissions} do
        post(
          :update_permissions,
          :params => {
            :permissions => {
              '1' => ['edit_issues']
            }
          }
        )
      end
    end
  end

  def test_move_highest
    put :update, :params => {:id => 3, :role => {:position => 1}}
    assert_redirected_to '/roles'
    assert_equal 1, Role.find(3).position
  end

  def test_move_higher
    position = Role.find(3).position
    put :update, :params => {:id => 3, :role => {:position => position - 1}}
    assert_redirected_to '/roles'
    assert_equal position - 1, Role.find(3).position
  end

  def test_move_lower
    position = Role.find(2).position
    put :update, :params => {:id => 2, :role => {:position => position + 1}}
    assert_redirected_to '/roles'
    assert_equal position + 1, Role.find(2).position
  end

  def test_move_lowest
    put :update, :params => {:id => 2, :role => {:position => Role.givable.count}}
    assert_redirected_to '/roles'
    assert_equal Role.givable.count, Role.find(2).position
  end
end
