# Redmine - project management software
# Copyright (C) 2006-2013  Jean-Philippe Lang
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

class WorkflowsControllerTest < ActionController::TestCase
  fixtures :roles, :trackers, :workflows, :users, :issue_statuses

  def setup
    User.current = nil
    @request.session[:user_id] = 1 # admin
  end

  def test_index
    get :index
    assert_response :success
    assert_template 'index'

    count = WorkflowTransition.where(:role_id => 1, :tracker_id => 2).count
    assert_tag :tag => 'a', :content => count.to_s,
                            :attributes => { :href => '/workflows/edit?role_id=1&amp;tracker_id=2' }
  end

  def test_get_edit
    get :edit
    assert_response :success
    assert_template 'edit'
    assert_not_nil assigns(:roles)
    assert_not_nil assigns(:trackers)
  end

  def test_get_edit_with_role_and_tracker
    WorkflowTransition.delete_all
    WorkflowTransition.create!(:role_id => 1, :tracker_id => 1, :old_status_id => 2, :new_status_id => 3)
    WorkflowTransition.create!(:role_id => 2, :tracker_id => 1, :old_status_id => 3, :new_status_id => 5)

    get :edit, :role_id => 2, :tracker_id => 1
    assert_response :success
    assert_template 'edit'

    # used status only
    assert_not_nil assigns(:statuses)
    assert_equal [2, 3, 5], assigns(:statuses).collect(&:id)

    # allowed transitions
    assert_tag :tag => 'input', :attributes => { :type => 'checkbox',
                                                 :name => 'issue_status[3][5][]',
                                                 :value => 'always',
                                                 :checked => 'checked' }
    # not allowed
    assert_tag :tag => 'input', :attributes => { :type => 'checkbox',
                                                 :name => 'issue_status[3][2][]',
                                                 :value => 'always',
                                                 :checked => nil }
    # unused
    assert_no_tag :tag => 'input', :attributes => { :type => 'checkbox',
                                                    :name => 'issue_status[1][1][]' }
  end

  def test_get_edit_with_role_and_tracker_and_all_statuses
    WorkflowTransition.delete_all

    get :edit, :role_id => 2, :tracker_id => 1, :used_statuses_only => '0'
    assert_response :success
    assert_template 'edit'

    assert_not_nil assigns(:statuses)
    assert_equal IssueStatus.count, assigns(:statuses).size

    assert_tag :tag => 'input', :attributes => { :type => 'checkbox',
                                                 :name => 'issue_status[1][1][]',
                                                 :value => 'always',
                                                 :checked => nil }
  end

  def test_post_edit
    post :edit, :role_id => 2, :tracker_id => 1,
      :issue_status => {
        '4' => {'5' => ['always']},
        '3' => {'1' => ['always'], '2' => ['always']}
      }
    assert_redirected_to '/workflows/edit?role_id=2&tracker_id=1'

    assert_equal 3, WorkflowTransition.where(:tracker_id => 1, :role_id => 2).count
    assert_not_nil  WorkflowTransition.where(:role_id => 2, :tracker_id => 1, :old_status_id => 3, :new_status_id => 2).first
    assert_nil      WorkflowTransition.where(:role_id => 2, :tracker_id => 1, :old_status_id => 5, :new_status_id => 4).first
  end

  def test_post_edit_with_additional_transitions
    post :edit, :role_id => 2, :tracker_id => 1,
      :issue_status => {
        '4' => {'5' => ['always']},
        '3' => {'1' => ['author'], '2' => ['assignee'], '4' => ['author', 'assignee']}
      }
    assert_redirected_to '/workflows/edit?role_id=2&tracker_id=1'

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

  def test_clear_workflow
    assert WorkflowTransition.where(:role_id => 1, :tracker_id => 2).count > 0

    post :edit, :role_id => 1, :tracker_id => 2
    assert_equal 0, WorkflowTransition.where(:role_id => 1, :tracker_id => 2).count
  end

  def test_get_permissions
    get :permissions

    assert_response :success
    assert_template 'permissions'
    assert_not_nil assigns(:roles)
    assert_not_nil assigns(:trackers)
  end

  def test_get_permissions_with_role_and_tracker
    WorkflowPermission.delete_all
    WorkflowPermission.create!(:role_id => 1, :tracker_id => 2, :old_status_id => 2, :field_name => 'assigned_to_id', :rule => 'required')
    WorkflowPermission.create!(:role_id => 1, :tracker_id => 2, :old_status_id => 2, :field_name => 'fixed_version_id', :rule => 'required')
    WorkflowPermission.create!(:role_id => 1, :tracker_id => 2, :old_status_id => 3, :field_name => 'fixed_version_id', :rule => 'readonly')

    get :permissions, :role_id => 1, :tracker_id => 2
    assert_response :success
    assert_template 'permissions'

    assert_select 'input[name=role_id][value=1]'
    assert_select 'input[name=tracker_id][value=2]'

    # Required field
    assert_select 'select[name=?]', 'permissions[assigned_to_id][2]' do
      assert_select 'option[value=]'
      assert_select 'option[value=][selected=selected]', 0
      assert_select 'option[value=readonly]', :text => 'Read-only'
      assert_select 'option[value=readonly][selected=selected]', 0
      assert_select 'option[value=required]', :text => 'Required'
      assert_select 'option[value=required][selected=selected]'
    end

    # Read-only field
    assert_select 'select[name=?]', 'permissions[fixed_version_id][3]' do
      assert_select 'option[value=]'
      assert_select 'option[value=][selected=selected]', 0
      assert_select 'option[value=readonly]', :text => 'Read-only'
      assert_select 'option[value=readonly][selected=selected]'
      assert_select 'option[value=required]', :text => 'Required'
      assert_select 'option[value=required][selected=selected]', 0
    end

    # Other field
    assert_select 'select[name=?]', 'permissions[due_date][3]' do
      assert_select 'option[value=]'
      assert_select 'option[value=][selected=selected]', 0
      assert_select 'option[value=readonly]', :text => 'Read-only'
      assert_select 'option[value=readonly][selected=selected]', 0
      assert_select 'option[value=required]', :text => 'Required'
      assert_select 'option[value=required][selected=selected]', 0
    end
  end

  def test_get_permissions_with_required_custom_field_should_not_show_required_option
    cf = IssueCustomField.create!(:name => 'Foo', :field_format => 'string', :tracker_ids => [1], :is_required => true)

    get :permissions, :role_id => 1, :tracker_id => 1
    assert_response :success
    assert_template 'permissions'

    # Custom field that is always required
    # The default option is "(Required)"
    assert_select 'select[name=?]', "permissions[#{cf.id}][3]" do
      assert_select 'option[value=]'
      assert_select 'option[value=readonly]', :text => 'Read-only'
      assert_select 'option[value=required]', 0
    end
  end

  def test_get_permissions_with_role_and_tracker_and_all_statuses
    WorkflowTransition.delete_all

    get :permissions, :role_id => 1, :tracker_id => 2, :used_statuses_only => '0'
    assert_response :success
    assert_equal IssueStatus.sorted.all, assigns(:statuses)
  end

  def test_post_permissions
    WorkflowPermission.delete_all

    post :permissions, :role_id => 1, :tracker_id => 2, :permissions => {
      'assigned_to_id' => {'1' => '', '2' => 'readonly', '3' => ''},
      'fixed_version_id' => {'1' => 'required', '2' => 'readonly', '3' => ''},
      'due_date' => {'1' => '', '2' => '', '3' => ''},
    }
    assert_redirected_to '/workflows/permissions?role_id=1&tracker_id=2'

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

  def test_post_permissions_should_clear_permissions
    WorkflowPermission.delete_all
    WorkflowPermission.create!(:role_id => 1, :tracker_id => 2, :old_status_id => 2, :field_name => 'assigned_to_id', :rule => 'required')
    WorkflowPermission.create!(:role_id => 1, :tracker_id => 2, :old_status_id => 2, :field_name => 'fixed_version_id', :rule => 'required')
    wf1 = WorkflowPermission.create!(:role_id => 1, :tracker_id => 3, :old_status_id => 2, :field_name => 'fixed_version_id', :rule => 'required')
    wf2 = WorkflowPermission.create!(:role_id => 2, :tracker_id => 2, :old_status_id => 3, :field_name => 'fixed_version_id', :rule => 'readonly')

    post :permissions, :role_id => 1, :tracker_id => 2
    assert_redirected_to '/workflows/permissions?role_id=1&tracker_id=2'

    workflows = WorkflowPermission.all
    assert_equal 2, workflows.size
    assert wf1.reload
    assert wf2.reload
  end

  def test_get_copy
    get :copy
    assert_response :success
    assert_template 'copy'
    assert_select 'select[name=source_tracker_id]' do
      assert_select 'option[value=1]', :text => 'Bug'
    end
    assert_select 'select[name=source_role_id]' do
      assert_select 'option[value=2]', :text => 'Developer'
    end
    assert_select 'select[name=?]', 'target_tracker_ids[]' do
      assert_select 'option[value=3]', :text => 'Support request'
    end
    assert_select 'select[name=?]', 'target_role_ids[]' do
      assert_select 'option[value=1]', :text => 'Manager'
    end
  end

  def test_post_copy_one_to_one
    source_transitions = status_transitions(:tracker_id => 1, :role_id => 2)

    post :copy, :source_tracker_id => '1', :source_role_id => '2',
                :target_tracker_ids => ['3'], :target_role_ids => ['1']
    assert_response 302
    assert_equal source_transitions, status_transitions(:tracker_id => 3, :role_id => 1)
  end

  def test_post_copy_one_to_many
    source_transitions = status_transitions(:tracker_id => 1, :role_id => 2)

    post :copy, :source_tracker_id => '1', :source_role_id => '2',
                :target_tracker_ids => ['2', '3'], :target_role_ids => ['1', '3']
    assert_response 302
    assert_equal source_transitions, status_transitions(:tracker_id => 2, :role_id => 1)
    assert_equal source_transitions, status_transitions(:tracker_id => 3, :role_id => 1)
    assert_equal source_transitions, status_transitions(:tracker_id => 2, :role_id => 3)
    assert_equal source_transitions, status_transitions(:tracker_id => 3, :role_id => 3)
  end

  def test_post_copy_many_to_many
    source_t2 = status_transitions(:tracker_id => 2, :role_id => 2)
    source_t3 = status_transitions(:tracker_id => 3, :role_id => 2)

    post :copy, :source_tracker_id => 'any', :source_role_id => '2',
                :target_tracker_ids => ['2', '3'], :target_role_ids => ['1', '3']
    assert_response 302
    assert_equal source_t2, status_transitions(:tracker_id => 2, :role_id => 1)
    assert_equal source_t3, status_transitions(:tracker_id => 3, :role_id => 1)
    assert_equal source_t2, status_transitions(:tracker_id => 2, :role_id => 3)
    assert_equal source_t3, status_transitions(:tracker_id => 3, :role_id => 3)
  end

  def test_post_copy_with_incomplete_source_specification_should_fail
    assert_no_difference 'WorkflowRule.count' do
      post :copy,
        :source_tracker_id => '', :source_role_id => '2',
        :target_tracker_ids => ['2', '3'], :target_role_ids => ['1', '3']
      assert_response 200
      assert_select 'div.flash.error', :text => 'Please select a source tracker or role' 
    end
  end

  def test_post_copy_with_incomplete_target_specification_should_fail
    assert_no_difference 'WorkflowRule.count' do
      post :copy,
        :source_tracker_id => '1', :source_role_id => '2',
        :target_tracker_ids => ['2', '3']
      assert_response 200
      assert_select 'div.flash.error', :text => 'Please select target tracker(s) and role(s)'
    end
  end

  # Returns an array of status transitions that can be compared
  def status_transitions(conditions)
    WorkflowTransition.
      where(conditions).
      order('tracker_id, role_id, old_status_id, new_status_id').
      all.
      collect {|w| [w.old_status, w.new_status_id]}
  end
end
