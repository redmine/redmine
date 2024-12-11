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

class TrackersControllerTest < Redmine::ControllerTest
  def setup
    User.current = nil
    @request.session[:user_id] = 1 # admin
  end

  def test_index
    get :index
    assert_response :success
    assert_select 'table.trackers'
  end

  def test_index_by_anonymous_should_redirect_to_login_form
    @request.session[:user_id] = nil
    get :index
    assert_redirected_to '/login?back_url=http%3A%2F%2Ftest.host%2Ftrackers'
  end

  def test_index_by_user_should_respond_with_406
    @request.session[:user_id] = 2
    get :index
    assert_response :not_acceptable
  end

  def test_new
    get :new
    assert_response :success
    assert_select 'input[name=?]', 'tracker[name]'
    assert_select 'select[name=?]', 'tracker[default_status_id]' do
      assert_select 'option[value=?][selected=selected]', IssueStatus.sorted.first.id.to_s
    end
  end

  def test_new_should_set_archived_class_for_archived_projects
    project = Project.find(2)
    project.update_attribute(:status, Project::STATUS_ARCHIVED)

    get :new
    assert_response :success
    assert_select '#tracker_project_ids ul li' do
      assert_select('> div[class*="archived"] input[name=?]', 'tracker[project_ids][]', 1) do
        assert_select ':match("value", ?)', project.id.to_s
      end
      assert_select '> div:not([class*="archived"]) input[name=?]', 'tracker[project_ids][]', Project.count - 1
    end
  end

  def test_new_with_copy
    core_fields = ['assigned_to_id', 'category_id', 'fixed_version_id', 'parent_issue_id', 'start_date', 'due_date']
    custom_field_ids = custom_field_ids = [1, 2, 6]
    project_ids = [1, 3, 5]

    copy_from = Tracker.find(1)
    copy_from.core_fields = core_fields
    copy_from.custom_field_ids = custom_field_ids
    copy_from.project_ids = project_ids
    copy_from.save

    get :new, :params => {:copy => copy_from.id.to_s}
    assert_response :success
    assert_select 'input[name=?]', 'tracker[name]'

    assert_select 'form' do
      # blank name
      assert_select 'input[name=?][value=""]', 'tracker[name]'
      # core field checked
      copy_from.core_fields.each do |core_field|
        assert_select "input[type=checkbox][name=?][value=#{core_field}][checked=checked]", 'tracker[core_fields][]'
      end
      # core field not checked
      copy_from.disabled_core_fields do |core_field|
        assert_select "input[type=checkbox][name=?][value=#{core_field}]", 'tracker[core_fields][]'
      end
      # custom field checked
      custom_field_ids.each do |custom_field_id|
        assert_select "input[type=checkbox][name=?][value=#{custom_field_id}][checked=checked]", 'tracker[custom_field_ids][]'
      end
      # custom field not checked
      (IssueCustomField.sorted.pluck(:id) - custom_field_ids).each do |custom_field_id|
        assert_select "input[type=checkbox][name=?][value=#{custom_field_id}]", 'tracker[custom_field_ids][]'
      end
      # project checked
      project_ids.each do |project_id|
        assert_select "input[type=checkbox][name=?][value=#{project_id}][checked=checked]", 'tracker[project_ids][]'
      end
      # project not checked
      (Project.pluck(:id) - project_ids).each do |project_id|
        assert_select "input[type=checkbox][name=?][value=#{project_id}]", 'tracker[project_ids][]'
      end
      # workflow copy selected
      assert_select 'select[name=?]', 'copy_workflow_from' do
        assert_select 'option[value="1"][selected=selected]'
      end
    end
  end

  def test_create
    assert_difference 'Tracker.count' do
      post :create, :params => {
        :tracker => {
          :name => 'New tracker',
          :default_status_id => 1,
          :project_ids => ['1', '', ''],
          :custom_field_ids => ['1', '6', '']
        }
      }
    end
    assert_redirected_to :action => 'index'
    tracker = Tracker.order('id DESC').first
    assert_equal 'New tracker', tracker.name
    assert_equal [1], tracker.project_ids.sort
    assert_equal Tracker::CORE_FIELDS, tracker.core_fields
    assert_equal [1, 6], tracker.custom_field_ids.sort
    assert_equal 0, tracker.workflow_rules.count
  end

  def test_create_with_disabled_core_fields
    assert_difference 'Tracker.count' do
      post :create, :params => {
        :tracker => {
          :name => 'New tracker',
          :default_status_id => 1,
          :core_fields => ['assigned_to_id', 'fixed_version_id', '']
        }
      }
    end
    assert_redirected_to :action => 'index'
    tracker = Tracker.order('id DESC').first
    assert_equal 'New tracker', tracker.name
    assert_equal %w(assigned_to_id fixed_version_id), tracker.core_fields
  end

  def test_create_new_with_workflow_copy
    assert_difference 'Tracker.count' do
      post :create, :params => {
        :tracker => {
          :name => 'New tracker',
          :default_status_id => 1
        },
        :copy_workflow_from => 1
      }
    end
    assert_redirected_to :action => 'index'
    tracker = Tracker.find_by_name('New tracker')
    assert_equal 0, tracker.projects.count
    assert_equal Tracker.find(1).workflow_rules.count, tracker.workflow_rules.count
  end

  def test_create_with_failure
    assert_no_difference 'Tracker.count' do
      post :create, :params => {
        :tracker => {
          :name => '',
          :project_ids => ['1', '', ''],
          :custom_field_ids => ['1', '6', '']
        }
      }
    end
    assert_response :success
    assert_select_error /name cannot be blank/i
  end

  def test_edit
    Tracker.find(1).project_ids = [1, 3]

    get :edit, :params => {:id => 1}
    assert_response :success

    assert_select 'input[name=?][value="1"][checked=checked]', 'tracker[project_ids][]'
    assert_select 'input[name=?][value="2"]:not([checked])', 'tracker[project_ids][]'

    assert_select 'input[name=?][value=""][type=hidden]', 'tracker[project_ids][]'
  end

  def test_edit_should_check_core_fields
    tracker = Tracker.find(1)
    tracker.core_fields = %w(assigned_to_id fixed_version_id)
    tracker.save!

    get :edit, :params => {:id => 1}
    assert_response :success

    assert_select 'input[name=?][value=assigned_to_id][checked=checked]', 'tracker[core_fields][]'
    assert_select 'input[name=?][value=fixed_version_id][checked=checked]', 'tracker[core_fields][]'

    assert_select 'input[name=?][value=category_id]', 'tracker[core_fields][]'
    assert_select 'input[name=?][value=category_id][checked=checked]', 'tracker[core_fields][]', 0

    assert_select 'input[name=?][value=priority_id]', 'tracker[core_fields][]'
    assert_select 'input[name=?][value=priority_id][checked=checked]', 'tracker[core_fields][]', 0

    assert_select 'input[name=?][value=""][type=hidden]', 'tracker[core_fields][]'
  end

  def test_update
    put :update, :params => {
      :id => 1,
      :tracker => {
        :name => 'Renamed',
        :project_ids => ['1', '2', '']
      }
    }
    assert_redirected_to :action => 'index'
    assert_equal [1, 2], Tracker.find(1).project_ids.sort
  end

  def test_update_without_projects
    put :update, :params => {
      :id => 1,
      :tracker => {
        :name => 'Renamed',
        :project_ids => ['']
      }
    }
    assert_redirected_to :action => 'index'
    assert Tracker.find(1).project_ids.empty?
  end

  def test_update_without_core_fields
    put :update, :params => {
      :id => 1,
      :tracker => {
        :name => 'Renamed',
        :core_fields => ['']
      }
    }
    assert_redirected_to :action => 'index'
    assert Tracker.find(1).core_fields.empty?
  end

  def test_update_with_failure
    put :update, :params => {:id => 1, :tracker => {:name => ''}}
    assert_response :success

    assert_select_error /name cannot be blank/i
  end

  def test_move_lower
    tracker = Tracker.find_by_position(1)
    put :update, :params => {:id => 1, :tracker => {:position => '2'}}
    assert_equal 2, tracker.reload.position
  end

  def test_destroy
    tracker = Tracker.generate!(:name => 'Destroyable')
    assert_difference 'Tracker.count', -1 do
      delete :destroy, :params => {:id => tracker.id}
    end
    assert_redirected_to :action => 'index'
    assert_nil flash[:error]
  end

  def test_destroy_tracker_in_use
    tracker = Tracker.generate!(name: 'In use')
    projects = Array.new(2) do
      project = Project.generate!
      Issue.generate!(project: project, tracker: tracker)
      project
    end

    assert_no_difference 'Tracker.count' do
      delete :destroy, params: {id: tracker.id}
    end
    assert_redirected_to action: 'index'
    assert_match /The following projects have issues with this tracker:/, flash[:error]
    projects.each do |project|
      assert_match /#{project.name}/, flash[:error]
    end
  end

  def test_get_fields
    get :fields
    assert_response :success

    assert_select 'form' do
      assert_select 'input[type=checkbox][name=?][value=assigned_to_id]', 'trackers[1][core_fields][]'
      assert_select 'input[type=checkbox][name=?][value="2"]', 'trackers[1][custom_field_ids][]'

      assert_select 'input[type=hidden][name=?][value=""]', 'trackers[1][core_fields][]'
      assert_select 'input[type=hidden][name=?][value=""]', 'trackers[1][custom_field_ids][]'
    end
  end

  def test_post_fields
    post :fields, :params => {
      :trackers => {
        '1' => {'core_fields' => ['assigned_to_id', 'due_date', ''], 'custom_field_ids' => ['1', '2']},
        '2' => {'core_fields' => [''], 'custom_field_ids' => ['']}
      }
    }
    assert_redirected_to '/trackers/fields'

    tracker = Tracker.find(1)
    assert_equal %w(assigned_to_id due_date), tracker.core_fields
    assert_equal [1, 2], tracker.custom_field_ids.sort

    tracker = Tracker.find(2)
    assert_equal [], tracker.core_fields
    assert_equal [], tracker.custom_field_ids.sort
  end
end
