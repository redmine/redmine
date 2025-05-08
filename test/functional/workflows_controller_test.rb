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

class WorkflowsControllerTest < Redmine::ControllerTest
  def setup
    User.current = nil
    @request.session[:user_id] = 1 # admin
  end

  def test_index
    get :index
    assert_response :success

    count = WorkflowTransition.where(:role_id => 1, :tracker_id => 2).count
    assert_select 'a[href=?]', '/workflows/edit?role_id=1&tracker_id=2', :content => count.to_s
  end

  def test_get_edit
    get :edit
    assert_response :success
  end

  def test_get_edit_with_role_and_tracker
    WorkflowTransition.delete_all
    WorkflowTransition.create!(:role_id => 1, :tracker_id => 1, :old_status_id => 2, :new_status_id => 3)
    WorkflowTransition.create!(:role_id => 2, :tracker_id => 1, :old_status_id => 3, :new_status_id => 5)

    get :edit, :params => {:role_id => 2, :tracker_id => 1}
    assert_response :success

    # used status only
    statuses = IssueStatus.where(:id => [2, 3, 5]).sorted.pluck(:name)
    assert_equal(
      ["New issue"] + statuses,
      css_select('table.workflows.transitions-always tbody tr td:first').map {|e| e.text.strip}
    )
    # allowed transitions
    assert_select 'input[type=checkbox][name=?][value="1"][checked=checked]', 'transitions[3][5][always]'
    # not allowed
    assert_select 'input[type=checkbox][name=?][value="1"]:not([checked=checked])', 'transitions[3][2][always]'
    # unused
    assert_select 'input[type=checkbox][name=?]', 'transitions[1][1][always]', 0
  end

  def test_get_edit_with_role_and_tracker_should_not_include_statuses_from_roles_without_workflow_permissions
    WorkflowTransition.delete_all
    WorkflowTransition.create!(:role_id => 1, :tracker_id => 1, :old_status_id => 2, :new_status_id => 3)

    reporter = Role.find(3)
    reporter.remove_permission! :edit_issues
    reporter.remove_permission! :add_issues
    assert !reporter.consider_workflow?
    WorkflowTransition.create!(:role_id => 3, :tracker_id => 1, :old_status_id => 1, :new_status_id => 5)

    get :edit, :params => {:role_id => 2, :tracker_id => 1}
    assert_response :success

    # statuses 1 and 5 not displayed
    statuses = IssueStatus.where(:id => [2, 3]).sorted.pluck(:name)
    assert_equal(
      ["New issue"] + statuses,
      css_select('table.workflows.transitions-always tbody tr td:first').map {|e| e.text.strip}
    )
  end

  def test_get_edit_with_role_and_tracker_should_not_include_only_identity_workflows
    WorkflowTransition.delete_all
    WorkflowTransition.create!(:role_id => 1, :tracker_id => 1, :old_status_id => 1, :new_status_id => 1)
    WorkflowTransition.create!(:role_id => 1, :tracker_id => 1, :old_status_id => 2, :new_status_id => 3)

    get :edit, :params => {:role_id => 1, :tracker_id => 1}
    assert_response :success

    # statuses 1 and 5 not displayed
    statuses = IssueStatus.where(:id => [2, 3]).sorted.pluck(:name)
    assert_equal(
      ["New issue"] + statuses,
      css_select('table.workflows.transitions-always tbody tr td:first').map {|e| e.text.strip}
    )
  end

  def test_get_edit_should_include_allowed_statuses_for_new_issues
    WorkflowTransition.delete_all
    WorkflowTransition.create!(:role_id => 1, :tracker_id => 1, :old_status_id => 0, :new_status_id => 1)

    get :edit, :params => {:role_id => 1, :tracker_id => 1}
    assert_response :success
    assert_select 'td', 'New issue'
    assert_select 'input[type=checkbox][name=?][value="1"][checked=checked]', 'transitions[0][1][always]'
  end

  def test_get_edit_with_all_roles_and_all_trackers
    get :edit, :params => {:role_id => 'all', :tracker_id => 'all'}
    assert_response :success

    assert_select 'select[name=?]', 'role_id[]' do
      assert_select 'option[selected=selected][value=all]'
    end
    assert_select 'select[name=?]', 'tracker_id[]' do
      assert_select 'option[selected=selected][value=all]'
    end
  end

  def test_get_edit_with_role_and_tracker_and_all_statuses
    WorkflowTransition.delete_all

    get :edit, :params => {:role_id => 2, :tracker_id => 1, :used_statuses_only => '0'}
    assert_response :success

    statuses = IssueStatus.all.sorted.pluck(:name)
    assert_equal(
      ["New issue"] + statuses,
      css_select('table.workflows.transitions-always tbody tr td:first').map {|e| e.text.strip}
    )
    assert_select 'input[type=checkbox][name=?]', 'transitions[0][1][always]'
  end

  def test_get_edit_should_show_checked_disabled_transition_checkbox_between_same_statuses
    get :edit, :params => {:role_id => 2, :tracker_id => 1}
    assert_response :success
    assert_select 'table.workflows.transitions-always tbody tr:nth-child(2)' do
      assert_select 'td.name', :text => 'New'
      # assert that the td is enabled
      assert_select "td.enabled[title='New » New']"
      # assert that the checkbox is disabled and checked
      assert_select "input[name='transitions[1][1][always]'][checked=?][disabled=?]", 'checked', 'disabled', 1
    end
  end

  def test_post_edit
    WorkflowTransition.delete_all

    patch :update, :params => {
      :role_id => 2,
      :tracker_id => 1,
      :transitions => {
        '4' => {'5' => {'always' => '1'}},
        '3' => {'1' => {'always' => '1'}, '2' => {'always' => '1'}}
      }
    }
    assert_response :found

    assert_equal 3, WorkflowTransition.where(:tracker_id => 1, :role_id => 2).count
    assert          WorkflowTransition.where(:role_id => 2, :tracker_id => 1, :old_status_id => 3, :new_status_id => 2).exists?
    assert_not      WorkflowTransition.where(:role_id => 2, :tracker_id => 1, :old_status_id => 5, :new_status_id => 4).exists?
  end

  def test_post_edit_with_allowed_statuses_for_new_issues
    WorkflowTransition.delete_all

    patch :update, :params => {
      :role_id => 2,
      :tracker_id => 1,
      :transitions => {
        '0' => {'1' => {'always' => '1'}, '2' => {'always' => '1'}}
      }
    }
    assert_response :found

    assert WorkflowTransition.where(:role_id => 2, :tracker_id => 1, :old_status_id => 0, :new_status_id => 1).any?
    assert WorkflowTransition.where(:role_id => 2, :tracker_id => 1, :old_status_id => 0, :new_status_id => 2).any?
    assert_equal 2, WorkflowTransition.where(:tracker_id => 1, :role_id => 2).count
  end

  def test_post_edit_with_additional_transitions
    WorkflowTransition.delete_all

    patch :update, :params => {
      :role_id => 2,
      :tracker_id => 1,
      :transitions => {
        '4' => {'5' => {'always' => '1', 'author' => '0', 'assignee' => '0'}},
        '3' => {'1' => {'always' => '0', 'author' => '1', 'assignee' => '0'},
                '2' => {'always' => '0', 'author' => '0', 'assignee' => '1'},
                '4' => {'always' => '0', 'author' => '1', 'assignee' => '1'}}
      }
    }
    assert_response :found

    assert_equal 4, WorkflowTransition.where(:tracker_id => 1, :role_id => 2).count

    w = WorkflowTransition.where(:role_id => 2, :tracker_id => 1, :old_status_id => 4, :new_status_id => 5).first
    assert ! w.author
    assert ! w.assignee
    w = WorkflowTransition.where(:role_id => 2, :tracker_id => 1, :old_status_id => 3, :new_status_id => 1).first
    assert w.author
    assert ! w.assignee
    w = WorkflowTransition.where(:role_id => 2, :tracker_id => 1, :old_status_id => 3, :new_status_id => 2).first
    assert ! w.author
    assert w.assignee
    w = WorkflowTransition.where(:role_id => 2, :tracker_id => 1, :old_status_id => 3, :new_status_id => 4).first
    assert w.author
    assert w.assignee
  end

  def test_get_permissions
    get :permissions

    assert_response :success
  end

  def test_get_permissions_with_role_and_tracker
    WorkflowPermission.delete_all
    WorkflowPermission.create!(:role_id => 1, :tracker_id => 2, :old_status_id => 2, :field_name => 'assigned_to_id', :rule => 'required')
    WorkflowPermission.create!(:role_id => 1, :tracker_id => 2, :old_status_id => 2, :field_name => 'fixed_version_id', :rule => 'required')
    WorkflowPermission.create!(:role_id => 1, :tracker_id => 2, :old_status_id => 3, :field_name => 'fixed_version_id', :rule => 'readonly')

    get :permissions, :params => {:role_id => 1, :tracker_id => 2}
    assert_response :success

    assert_select 'input[name=?][value="1"]', 'role_id[]'
    assert_select 'input[name=?][value="2"]', 'tracker_id[]'

    # Required field
    assert_select 'select[name=?]', 'permissions[2][assigned_to_id]' do
      assert_select 'option[value=""]'
      assert_select 'option[value=""][selected=selected]', 0
      assert_select 'option[value=readonly]', :text => 'Read-only'
      assert_select 'option[value=readonly][selected=selected]', 0
      assert_select 'option[value=required]', :text => 'Required'
      assert_select 'option[value=required][selected=selected]'
    end

    # Read-only field
    assert_select 'select[name=?]', 'permissions[3][fixed_version_id]' do
      assert_select 'option[value=""]'
      assert_select 'option[value=""][selected=selected]', 0
      assert_select 'option[value=readonly]', :text => 'Read-only'
      assert_select 'option[value=readonly][selected=selected]'
      assert_select 'option[value=required]', :text => 'Required'
      assert_select 'option[value=required][selected=selected]', 0
    end

    # Other field
    assert_select 'select[name=?]', 'permissions[3][due_date]' do
      assert_select 'option[value=""]'
      assert_select 'option[value=""][selected=selected]', 0
      assert_select 'option[value=readonly]', :text => 'Read-only'
      assert_select 'option[value=readonly][selected=selected]', 0
      assert_select 'option[value=required]', :text => 'Required'
      assert_select 'option[value=required][selected=selected]', 0
    end
  end

  def test_get_permissions_with_required_custom_field_should_not_show_required_option
    cf = IssueCustomField.create!(:name => 'Foo', :field_format => 'string', :tracker_ids => [1], :is_required => true)

    get :permissions, :params => {:role_id => 1, :tracker_id => 1}
    assert_response :success

    # Custom field that is always required
    # The default option is "(Required)"
    assert_select 'select[name=?]', "permissions[3][#{cf.id}]" do
      assert_select 'option[value=""]'
      assert_select 'option[value=readonly]', :text => 'Read-only'
      assert_select 'option[value=required]', 0
    end
  end

  def test_get_permissions_should_disable_hidden_custom_fields
    cf1 = IssueCustomField.generate!(:tracker_ids => [1], :visible => true)
    cf2 = IssueCustomField.generate!(:tracker_ids => [1], :visible => false, :role_ids => [1])
    cf3 = IssueCustomField.generate!(:tracker_ids => [1], :visible => false, :role_ids => [1, 2])

    get :permissions, :params => {:role_id => 2, :tracker_id => 1}
    assert_response :success

    assert_select 'select[name=?]:not(.disabled)', "permissions[1][#{cf1.id}]"
    assert_select 'select[name=?]:not(.disabled)', "permissions[1][#{cf3.id}]"

    assert_select 'select[name=?][disabled=disabled]', "permissions[1][#{cf2.id}]" do
      assert_select 'option[value=""][selected=selected]', :text => 'Hidden'
    end
  end

  def test_get_permissions_with_missing_permissions_for_roles_should_default_to_no_change
    WorkflowPermission.delete_all
    WorkflowPermission.create!(:role_id => 1, :tracker_id => 2, :old_status_id => 1, :field_name => 'assigned_to_id', :rule => 'required')

    get :permissions, :params => {:role_id => [1, 2], :tracker_id => 2}
    assert_response :success

    assert_select 'select[name=?]', 'permissions[1][assigned_to_id]' do
      assert_select 'option[selected]', 1
      assert_select 'option[selected][value=no_change]'
    end
  end

  def test_get_permissions_with_different_permissions_for_roles_should_default_to_no_change
    WorkflowPermission.delete_all
    WorkflowPermission.create!(:role_id => 1, :tracker_id => 2, :old_status_id => 1, :field_name => 'assigned_to_id', :rule => 'required')
    WorkflowPermission.create!(:role_id => 2, :tracker_id => 2, :old_status_id => 1, :field_name => 'assigned_to_id', :rule => 'readonly')

    get :permissions, :params => {:role_id => [1, 2], :tracker_id => 2}
    assert_response :success

    assert_select 'select[name=?]', 'permissions[1][assigned_to_id]' do
      assert_select 'option[selected]', 1
      assert_select 'option[selected][value=no_change]'
    end
  end

  def test_get_permissions_with_same_permissions_for_roles_should_default_to_permission
    WorkflowPermission.delete_all
    WorkflowPermission.create!(:role_id => 1, :tracker_id => 2, :old_status_id => 1, :field_name => 'assigned_to_id', :rule => 'required')
    WorkflowPermission.create!(:role_id => 2, :tracker_id => 2, :old_status_id => 1, :field_name => 'assigned_to_id', :rule => 'required')

    get :permissions, :params => {:role_id => [1, 2], :tracker_id => 2}
    assert_response :success

    assert_select 'select[name=?]', 'permissions[1][assigned_to_id]' do
      assert_select 'option[selected]', 1
      assert_select 'option[selected][value=required]'
    end
  end

  def test_get_permissions_with_role_and_tracker_and_all_statuses_should_show_all_statuses
    WorkflowTransition.delete_all

    get :permissions, :params => {:role_id => 1, :tracker_id => 2, :used_statuses_only => '0'}
    assert_response :success

    statuses = IssueStatus.all.sorted.pluck(:name)
    assert_equal(
      statuses,
      css_select('table.workflows.fields_permissions thead tr:nth-child(2) td:not(:first-child)').map {|e| e.text.strip}
    )
  end

  def test_get_permissions_should_set_css_class
    WorkflowPermission.delete_all
    WorkflowPermission.create!(:role_id => 1, :tracker_id => 2, :old_status_id => 1, :field_name => 'assigned_to_id', :rule => 'required')
    cf = IssueCustomField.create!(:name => 'Foo', :field_format => 'string', :tracker_ids => [2])
    WorkflowPermission.create!(:role_id => 1, :tracker_id => 2, :old_status_id => 1, :field_name => cf.id, :rule => 'required')

    get :permissions, :params => {:role_id => 1, :tracker_id => 2}
    assert_response :success
    assert_select 'td.required > select[name=?]', 'permissions[1][assigned_to_id]'
    assert_select 'td.required > select[name=?]', "permissions[1][#{cf.id}]"
  end

  def test_post_permissions
    WorkflowPermission.delete_all

    patch :update_permissions, :params => {
      :role_id => 1,
      :tracker_id => 2,
      :permissions => {
        '1' => {'assigned_to_id' => '', 'fixed_version_id' => 'required', 'due_date' => ''},
        '2' => {'assigned_to_id' => 'readonly', 'fixed_version_id' => 'readonly', 'due_date' => ''},
        '3' => {'assigned_to_id' => '',  'fixed_version_id' => '', 'due_date' => ''}
      }
    }
    assert_response :found

    workflows = WorkflowPermission.all
    assert_equal 3, workflows.size
    workflows.each do |workflow|
      assert_equal 1, workflow.role_id
      assert_equal 2, workflow.tracker_id
    end
    assert workflows.detect {|wf| wf.old_status_id == 2 && wf.field_name == 'assigned_to_id' && wf.rule == 'readonly'}
    assert workflows.detect {|wf| wf.old_status_id == 1 && wf.field_name == 'fixed_version_id' && wf.rule == 'required'}
    assert workflows.detect {|wf| wf.old_status_id == 2 && wf.field_name == 'fixed_version_id' && wf.rule == 'readonly'}
  end

  def test_get_copy
    get :copy
    assert_response :success

    assert_select 'select[name=source_tracker_id]' do
      assert_select 'option[value="1"]', :text => 'Bug'
    end
    assert_select 'select[name=source_role_id]' do
      assert_select 'option[value="2"]', :text => 'Developer'
    end
    assert_select 'select[name=?]', 'target_tracker_ids[]' do
      assert_select 'option[value="3"]', :text => 'Support request'
    end
    assert_select 'select[name=?]', 'target_role_ids[]' do
      assert_select 'option[value="1"]', :text => 'Manager'
    end
  end

  def test_post_copy_one_to_one
    source_transitions = status_transitions(:tracker_id => 1, :role_id => 2)

    post :duplicate, :params => {
      :source_tracker_id => '1', :source_role_id => '2',
      :target_tracker_ids => ['3'], :target_role_ids => ['1']
    }
    assert_response :found
    assert_equal source_transitions, status_transitions(:tracker_id => 3, :role_id => 1)
  end

  def test_post_copy_one_to_many
    source_transitions = status_transitions(:tracker_id => 1, :role_id => 2)

    post :duplicate, :params => {
      :source_tracker_id => '1', :source_role_id => '2',
      :target_tracker_ids => ['2', '3'], :target_role_ids => ['1', '3']
    }
    assert_response :found
    assert_equal source_transitions, status_transitions(:tracker_id => 2, :role_id => 1)
    assert_equal source_transitions, status_transitions(:tracker_id => 3, :role_id => 1)
    assert_equal source_transitions, status_transitions(:tracker_id => 2, :role_id => 3)
    assert_equal source_transitions, status_transitions(:tracker_id => 3, :role_id => 3)
  end

  def test_post_copy_many_to_many
    source_t2 = status_transitions(:tracker_id => 2, :role_id => 2)
    source_t3 = status_transitions(:tracker_id => 3, :role_id => 2)

    post :duplicate, :params => {
      :source_tracker_id => 'any', :source_role_id => '2',
      :target_tracker_ids => ['2', '3'], :target_role_ids => ['1', '3']
    }
    assert_response :found
    assert_equal source_t2, status_transitions(:tracker_id => 2, :role_id => 1)
    assert_equal source_t3, status_transitions(:tracker_id => 3, :role_id => 1)
    assert_equal source_t2, status_transitions(:tracker_id => 2, :role_id => 3)
    assert_equal source_t3, status_transitions(:tracker_id => 3, :role_id => 3)
  end

  def test_post_copy_with_incomplete_source_specification_should_fail
    assert_no_difference 'WorkflowRule.count' do
      post :duplicate, :params => {
        :source_tracker_id => '', :source_role_id => '2',
        :target_tracker_ids => ['2', '3'], :target_role_ids => ['1', '3']
      }
      assert_response :ok
      assert_select 'div.flash.error', :text => 'Please select a source tracker or role'
    end
  end

  def test_post_copy_with_incomplete_target_specification_should_fail
    assert_no_difference 'WorkflowRule.count' do
      post :duplicate, :params => {
        :source_tracker_id => '1', :source_role_id => '2',
        :target_tracker_ids => ['2', '3']
      }
      assert_response :ok
      assert_select 'div.flash.error', :text => 'Please select target tracker(s) and role(s)'
    end
  end

  # Returns an array of status transitions that can be compared
  def status_transitions(conditions)
    WorkflowTransition.
      where(conditions).
      order('tracker_id, role_id, old_status_id, new_status_id').
      collect {|w| [w.old_status, w.new_status_id]}
  end
end
