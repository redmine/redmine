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

class TrackersControllerTest < ActionController::TestCase
  fixtures :trackers, :projects, :projects_trackers, :users, :issues, :custom_fields, :issue_statuses

  def setup
    User.current = nil
    @request.session[:user_id] = 1 # admin
  end

  def test_index
    get :index
    assert_response :success
    assert_template 'index'
  end
  
  def test_index_by_anonymous_should_redirect_to_login_form
    @request.session[:user_id] = nil
    get :index
    assert_redirected_to '/login?back_url=http%3A%2F%2Ftest.host%2Ftrackers'
  end
  
  def test_index_by_user_should_respond_with_406
    @request.session[:user_id] = 2
    get :index
    assert_response 406
  end

  def test_new
    get :new
    assert_response :success
    assert_template 'new'
  end

  def test_create
    assert_difference 'Tracker.count' do
      post :create, :tracker => { :name => 'New tracker', :default_status_id => 1, :project_ids => ['1', '', ''], :custom_field_ids => ['1', '6', ''] }
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
      post :create, :tracker => { :name => 'New tracker', :default_status_id => 1, :core_fields => ['assigned_to_id', 'fixed_version_id', ''] }
    end
    assert_redirected_to :action => 'index'
    tracker = Tracker.order('id DESC').first
    assert_equal 'New tracker', tracker.name
    assert_equal %w(assigned_to_id fixed_version_id), tracker.core_fields
  end

  def test_create_new_with_workflow_copy
    assert_difference 'Tracker.count' do
      post :create, :tracker => { :name => 'New tracker', :default_status_id => 1 }, :copy_workflow_from => 1
    end
    assert_redirected_to :action => 'index'
    tracker = Tracker.find_by_name('New tracker')
    assert_equal 0, tracker.projects.count
    assert_equal Tracker.find(1).workflow_rules.count, tracker.workflow_rules.count
  end

  def test_create_with_failure
    assert_no_difference 'Tracker.count' do
      post :create, :tracker => { :name => '', :project_ids => ['1', '', ''],
                                  :custom_field_ids => ['1', '6', ''] }
    end
    assert_response :success
    assert_template 'new'
    assert_select_error /name cannot be blank/i
  end

  def test_edit
    Tracker.find(1).project_ids = [1, 3]

    get :edit, :id => 1
    assert_response :success
    assert_template 'edit'

    assert_select 'input[name=?][value="1"][checked=checked]', 'tracker[project_ids][]'
    assert_select 'input[name=?][value="2"]:not([checked])', 'tracker[project_ids][]'

    assert_select 'input[name=?][value=""][type=hidden]', 'tracker[project_ids][]'
  end

  def test_edit_should_check_core_fields
    tracker = Tracker.find(1)
    tracker.core_fields = %w(assigned_to_id fixed_version_id)
    tracker.save!

    get :edit, :id => 1
    assert_response :success
    assert_template 'edit'

    assert_select 'input[name=?][value=assigned_to_id][checked=checked]', 'tracker[core_fields][]'
    assert_select 'input[name=?][value=fixed_version_id][checked=checked]', 'tracker[core_fields][]'

    assert_select 'input[name=?][value=category_id]', 'tracker[core_fields][]'
    assert_select 'input[name=?][value=category_id][checked=checked]', 'tracker[core_fields][]', 0

    assert_select 'input[name=?][value=""][type=hidden]', 'tracker[core_fields][]'
  end

  def test_update
    put :update, :id => 1, :tracker => { :name => 'Renamed',
                                        :project_ids => ['1', '2', ''] }
    assert_redirected_to :action => 'index'
    assert_equal [1, 2], Tracker.find(1).project_ids.sort
  end

  def test_update_without_projects
    put :update, :id => 1, :tracker => { :name => 'Renamed',
                                        :project_ids => [''] }
    assert_redirected_to :action => 'index'
    assert Tracker.find(1).project_ids.empty?
  end

  def test_update_without_core_fields
    put :update, :id => 1, :tracker => { :name => 'Renamed', :core_fields => [''] }
    assert_redirected_to :action => 'index'
    assert Tracker.find(1).core_fields.empty?
  end

  def test_update_with_failure
    put :update, :id => 1, :tracker => { :name => '' }
    assert_response :success
    assert_template 'edit'
    assert_select_error /name cannot be blank/i
  end

  def test_move_lower
   tracker = Tracker.find_by_position(1)
   put :update, :id => 1, :tracker => { :position => '2' }
   assert_equal 2, tracker.reload.position
  end

  def test_destroy
    tracker = Tracker.generate!(:name => 'Destroyable')
    assert_difference 'Tracker.count', -1 do
      delete :destroy, :id => tracker.id
    end
    assert_redirected_to :action => 'index'
    assert_nil flash[:error]
  end

  def test_destroy_tracker_in_use
    assert_no_difference 'Tracker.count' do
      delete :destroy, :id => 1
    end
    assert_redirected_to :action => 'index'
    assert_not_nil flash[:error]
  end

  def test_get_fields
    get :fields
    assert_response :success
    assert_template 'fields'

    assert_select 'form' do
      assert_select 'input[type=checkbox][name=?][value=assigned_to_id]', 'trackers[1][core_fields][]'
      assert_select 'input[type=checkbox][name=?][value="2"]', 'trackers[1][custom_field_ids][]'

      assert_select 'input[type=hidden][name=?][value=""]', 'trackers[1][core_fields][]'
      assert_select 'input[type=hidden][name=?][value=""]', 'trackers[1][custom_field_ids][]'
    end
  end

  def test_post_fields
    post :fields, :trackers => {
      '1' => {'core_fields' => ['assigned_to_id', 'due_date', ''], 'custom_field_ids' => ['1', '2']},
      '2' => {'core_fields' => [''], 'custom_field_ids' => ['']}
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
