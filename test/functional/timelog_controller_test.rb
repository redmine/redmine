# -*- coding: utf-8 -*-
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

class TimelogControllerTest < ActionController::TestCase
  fixtures :projects, :enabled_modules, :roles, :members,
           :member_roles, :issues, :time_entries, :users,
           :trackers, :enumerations, :issue_statuses,
           :custom_fields, :custom_values,
           :projects_trackers, :custom_fields_trackers,
           :custom_fields_projects

  include Redmine::I18n

  def test_new
    @request.session[:user_id] = 3
    get :new
    assert_response :success
    assert_template 'new'
    assert_select 'input[name=?][type=hidden]', 'project_id', 0
    assert_select 'input[name=?][type=hidden]', 'issue_id', 0
    assert_select 'select[name=?]', 'time_entry[project_id]' do
      # blank option for project
      assert_select 'option[value=""]'
    end
  end

  def test_new_with_project_id
    @request.session[:user_id] = 3
    get :new, :project_id => 1
    assert_response :success
    assert_template 'new'
    assert_select 'input[name=?][type=hidden]', 'project_id'
    assert_select 'input[name=?][type=hidden]', 'issue_id', 0
    assert_select 'select[name=?]', 'time_entry[project_id]', 0
  end

  def test_new_with_issue_id
    @request.session[:user_id] = 3
    get :new, :issue_id => 2
    assert_response :success
    assert_template 'new'
    assert_select 'input[name=?][type=hidden]', 'project_id', 0
    assert_select 'input[name=?][type=hidden]', 'issue_id'
    assert_select 'select[name=?]', 'time_entry[project_id]', 0
  end

  def test_new_without_project_should_prefill_the_form
    @request.session[:user_id] = 3
    get :new, :time_entry => {:project_id => '1'}
    assert_response :success
    assert_template 'new'
    assert_select 'select[name=?]', 'time_entry[project_id]' do
      assert_select 'option[value="1"][selected=selected]'
    end
  end

  def test_new_without_project_should_deny_without_permission
    Role.all.each {|role| role.remove_permission! :log_time}
    @request.session[:user_id] = 3

    get :new
    assert_response 403
  end

  def test_new_should_select_default_activity
    @request.session[:user_id] = 3
    get :new, :project_id => 1
    assert_response :success
    assert_select 'select[name=?]', 'time_entry[activity_id]' do
      assert_select 'option[selected=selected]', :text => 'Development'
    end
  end

  def test_new_should_only_show_active_time_entry_activities
    @request.session[:user_id] = 3
    get :new, :project_id => 1
    assert_response :success
    assert_select 'option', :text => 'Inactive Activity', :count => 0
  end

  def test_post_new_as_js_should_update_activity_options
    @request.session[:user_id] = 3
    post :new, :time_entry => {:project_id => 1}, :format => 'js'
    assert_response :success
    assert_include '#time_entry_activity_id', response.body
  end

  def test_get_edit_existing_time
    @request.session[:user_id] = 2
    get :edit, :id => 2, :project_id => nil
    assert_response :success
    assert_template 'edit'
    assert_select 'form[action=?]', '/time_entries/2'
  end

  def test_get_edit_with_an_existing_time_entry_with_inactive_activity
    te = TimeEntry.find(1)
    te.activity = TimeEntryActivity.find_by_name("Inactive Activity")
    te.save!(:validate => false)

    @request.session[:user_id] = 1
    get :edit, :project_id => 1, :id => 1
    assert_response :success
    assert_template 'edit'
    # Blank option since nothing is pre-selected
    assert_select 'option', :text => '--- Please select ---'
  end

  def test_post_create
    @request.session[:user_id] = 3
    assert_difference 'TimeEntry.count' do
      post :create, :project_id => 1,
                :time_entry => {:comments => 'Some work on TimelogControllerTest',
                                # Not the default activity
                                :activity_id => '11',
                                :spent_on => '2008-03-14',
                                :issue_id => '1',
                                :hours => '7.3'}
      assert_redirected_to '/projects/ecookbook/time_entries'
    end

    t = TimeEntry.order('id DESC').first
    assert_not_nil t
    assert_equal 'Some work on TimelogControllerTest', t.comments
    assert_equal 1, t.project_id
    assert_equal 1, t.issue_id
    assert_equal 11, t.activity_id
    assert_equal 7.3, t.hours
    assert_equal 3, t.user_id
  end

  def test_post_create_with_blank_issue
    @request.session[:user_id] = 3
    assert_difference 'TimeEntry.count' do
      post :create, :project_id => 1,
                :time_entry => {:comments => 'Some work on TimelogControllerTest',
                                # Not the default activity
                                :activity_id => '11',
                                :issue_id => '',
                                :spent_on => '2008-03-14',
                                :hours => '7.3'}
      assert_redirected_to '/projects/ecookbook/time_entries'
    end

    t = TimeEntry.order('id DESC').first
    assert_not_nil t
    assert_equal 'Some work on TimelogControllerTest', t.comments
    assert_equal 1, t.project_id
    assert_nil t.issue_id
    assert_equal 11, t.activity_id
    assert_equal 7.3, t.hours
    assert_equal 3, t.user_id
  end

  def test_create_on_project_with_time_tracking_disabled_should_fail
    Project.find(1).disable_module! :time_tracking

    @request.session[:user_id] = 2
    assert_no_difference 'TimeEntry.count' do
      post :create, :time_entry => {
        :project_id => '1', :issue_id => '',
        :activity_id => '11', :spent_on => '2008-03-14', :hours => '7.3'
      }
    end
  end

  def test_create_on_project_without_permission_should_fail
    Role.find(1).remove_permission! :log_time

    @request.session[:user_id] = 2
    assert_no_difference 'TimeEntry.count' do
      post :create, :time_entry => {
        :project_id => '1', :issue_id => '',
        :activity_id => '11', :spent_on => '2008-03-14', :hours => '7.3'
      }
    end
  end

  def test_create_on_issue_in_project_with_time_tracking_disabled_should_fail
    Project.find(1).disable_module! :time_tracking

    @request.session[:user_id] = 2
    assert_no_difference 'TimeEntry.count' do
      post :create, :time_entry => {
        :project_id => '', :issue_id => '1',
        :activity_id => '11', :spent_on => '2008-03-14', :hours => '7.3'
      }
      assert_select_error /Issue is invalid/
    end
  end

  def test_create_on_issue_in_project_without_permission_should_fail
    Role.find(1).remove_permission! :log_time

    @request.session[:user_id] = 2
    assert_no_difference 'TimeEntry.count' do
      post :create, :time_entry => {
        :project_id => '', :issue_id => '1',
        :activity_id => '11', :spent_on => '2008-03-14', :hours => '7.3'
      }
      assert_select_error /Issue is invalid/
    end
  end

  def test_create_on_issue_that_is_not_visible_should_not_disclose_subject
    issue = Issue.generate!(:subject => "issue_that_is_not_visible", :is_private => true)
    assert !issue.visible?(User.find(3))

    @request.session[:user_id] = 3
    assert_no_difference 'TimeEntry.count' do
      post :create, :time_entry => {
        :project_id => '', :issue_id => issue.id.to_s,
        :activity_id => '11', :spent_on => '2008-03-14', :hours => '7.3'
      }
    end
    assert_select_error /Issue is invalid/
    assert_select "input[name=?][value=?]", "time_entry[issue_id]", issue.id.to_s
    assert_select "#time_entry_issue", 0
    assert !response.body.include?('issue_that_is_not_visible')
  end

  def test_create_and_continue_at_project_level
    @request.session[:user_id] = 2
    assert_difference 'TimeEntry.count' do
      post :create, :time_entry => {:project_id => '1',
                                    :activity_id => '11',
                                    :issue_id => '',
                                    :spent_on => '2008-03-14',
                                    :hours => '7.3'},
                    :continue => '1'
      assert_redirected_to '/time_entries/new?time_entry%5Bactivity_id%5D=11&time_entry%5Bissue_id%5D=&time_entry%5Bproject_id%5D=1'
    end
  end

  def test_create_and_continue_at_issue_level
    @request.session[:user_id] = 2
    assert_difference 'TimeEntry.count' do
      post :create, :time_entry => {:project_id => '',
                                    :activity_id => '11',
                                    :issue_id => '1',
                                    :spent_on => '2008-03-14',
                                    :hours => '7.3'},
                    :continue => '1'
      assert_redirected_to '/time_entries/new?time_entry%5Bactivity_id%5D=11&time_entry%5Bissue_id%5D=1&time_entry%5Bproject_id%5D='
    end
  end

  def test_create_and_continue_with_project_id
    @request.session[:user_id] = 2
    assert_difference 'TimeEntry.count' do
      post :create, :project_id => 1,
                    :time_entry => {:activity_id => '11',
                                    :issue_id => '',
                                    :spent_on => '2008-03-14',
                                    :hours => '7.3'},
                    :continue => '1'
      assert_redirected_to '/projects/ecookbook/time_entries/new?time_entry%5Bactivity_id%5D=11&time_entry%5Bissue_id%5D=&time_entry%5Bproject_id%5D='
    end
  end

  def test_create_and_continue_with_issue_id
    @request.session[:user_id] = 2
    assert_difference 'TimeEntry.count' do
      post :create, :issue_id => 1,
                    :time_entry => {:activity_id => '11',
                                    :issue_id => '1',
                                    :spent_on => '2008-03-14',
                                    :hours => '7.3'},
                    :continue => '1'
      assert_redirected_to '/issues/1/time_entries/new?time_entry%5Bactivity_id%5D=11&time_entry%5Bissue_id%5D=1&time_entry%5Bproject_id%5D='
    end
  end

  def test_create_without_log_time_permission_should_be_denied
    @request.session[:user_id] = 2
    Role.find_by_name('Manager').remove_permission! :log_time
    post :create, :project_id => 1,
                :time_entry => {:activity_id => '11',
                                :issue_id => '',
                                :spent_on => '2008-03-14',
                                :hours => '7.3'}

    assert_response 403
  end

  def test_create_without_project_and_issue_should_fail
    @request.session[:user_id] = 2
    post :create, :time_entry => {:issue_id => ''}

    assert_response :success
    assert_template 'new'
  end

  def test_create_with_failure
    @request.session[:user_id] = 2
    post :create, :project_id => 1,
                :time_entry => {:activity_id => '',
                                :issue_id => '',
                                :spent_on => '2008-03-14',
                                :hours => '7.3'}

    assert_response :success
    assert_template 'new'
  end

  def test_create_without_project
    @request.session[:user_id] = 2
    assert_difference 'TimeEntry.count' do
      post :create, :time_entry => {:project_id => '1',
                                  :activity_id => '11',
                                  :issue_id => '',
                                  :spent_on => '2008-03-14',
                                  :hours => '7.3'}
    end

    assert_redirected_to '/projects/ecookbook/time_entries'
    time_entry = TimeEntry.order('id DESC').first
    assert_equal 1, time_entry.project_id
  end

  def test_create_without_project_should_fail_with_issue_not_inside_project
    @request.session[:user_id] = 2
    assert_no_difference 'TimeEntry.count' do
      post :create, :time_entry => {:project_id => '1',
                                  :activity_id => '11',
                                  :issue_id => '5',
                                  :spent_on => '2008-03-14',
                                  :hours => '7.3'}
    end

    assert_response :success
    assert assigns(:time_entry).errors[:issue_id].present?
  end

  def test_create_without_project_should_deny_without_permission
    @request.session[:user_id] = 2
    Project.find(3).disable_module!(:time_tracking)

    assert_no_difference 'TimeEntry.count' do
      post :create, :time_entry => {:project_id => '3',
                                  :activity_id => '11',
                                  :issue_id => '',
                                  :spent_on => '2008-03-14',
                                  :hours => '7.3'}
    end

    assert_response 403
  end

  def test_create_without_project_with_failure
    @request.session[:user_id] = 2
    assert_no_difference 'TimeEntry.count' do
      post :create, :time_entry => {:project_id => '1',
                                  :activity_id => '11',
                                  :issue_id => '',
                                  :spent_on => '2008-03-14',
                                  :hours => ''}
    end

    assert_response :success
    assert_select 'select[name=?]', 'time_entry[project_id]' do
      assert_select 'option[value="1"][selected=selected]'
    end
  end

  def test_update
    entry = TimeEntry.find(1)
    assert_equal 1, entry.issue_id
    assert_equal 2, entry.user_id

    @request.session[:user_id] = 1
    put :update, :id => 1,
                :time_entry => {:issue_id => '2',
                                :hours => '8'}
    assert_redirected_to :action => 'index', :project_id => 'ecookbook'
    entry.reload

    assert_equal 8, entry.hours
    assert_equal 2, entry.issue_id
    assert_equal 2, entry.user_id
  end

  def test_update_should_allow_to_change_issue_to_another_project
    entry = TimeEntry.generate!(:issue_id => 1)

    @request.session[:user_id] = 1
    put :update, :id => entry.id, :time_entry => {:issue_id => '5'}
    assert_response 302
    entry.reload

    assert_equal 5, entry.issue_id
    assert_equal 3, entry.project_id
  end

  def test_update_should_not_allow_to_change_issue_to_an_invalid_project
    entry = TimeEntry.generate!(:issue_id => 1)
    Project.find(3).disable_module!(:time_tracking)

    @request.session[:user_id] = 1
    put :update, :id => entry.id, :time_entry => {:issue_id => '5'}
    assert_response 200
    assert_include "Issue is invalid", assigns(:time_entry).errors.full_messages
  end

  def test_get_bulk_edit
    @request.session[:user_id] = 2
    get :bulk_edit, :ids => [1, 2]
    assert_response :success
    assert_template 'bulk_edit'

    assert_select 'ul#bulk-selection' do
      assert_select 'li', 2
      assert_select 'li a', :text => '03/23/2007 - eCookbook: 4.25 hours'
    end

    assert_select 'form#bulk_edit_form[action=?]', '/time_entries/bulk_update' do
      # System wide custom field
      assert_select 'select[name=?]', 'time_entry[custom_field_values][10]'
  
      # Activities
      assert_select 'select[name=?]', 'time_entry[activity_id]' do
        assert_select 'option[value=""]', :text => '(No change)'
        assert_select 'option[value="9"]', :text => 'Design'
      end
    end
  end

  def test_get_bulk_edit_on_different_projects
    @request.session[:user_id] = 2
    get :bulk_edit, :ids => [1, 2, 6]
    assert_response :success
    assert_template 'bulk_edit'
  end

  def test_bulk_edit_with_edit_own_time_entries_permission
    @request.session[:user_id] = 2
    Role.find_by_name('Manager').remove_permission! :edit_time_entries
    Role.find_by_name('Manager').add_permission! :edit_own_time_entries
    ids = (0..1).map {TimeEntry.generate!(:user => User.find(2)).id}

    get :bulk_edit, :ids => ids
    assert_response :success
  end

  def test_bulk_update
    @request.session[:user_id] = 2
    # update time entry activity
    post :bulk_update, :ids => [1, 2], :time_entry => { :activity_id => 9}

    assert_response 302
    # check that the issues were updated
    assert_equal [9, 9], TimeEntry.where(:id => [1, 2]).collect {|i| i.activity_id}
  end

  def test_bulk_update_with_failure
    @request.session[:user_id] = 2
    post :bulk_update, :ids => [1, 2], :time_entry => { :hours => 'A'}

    assert_response 302
    assert_match /Failed to save 2 time entrie/, flash[:error]
  end

  def test_bulk_update_on_different_projects
    @request.session[:user_id] = 2
    # makes user a manager on the other project
    Member.create!(:user_id => 2, :project_id => 3, :role_ids => [1])
    
    # update time entry activity
    post :bulk_update, :ids => [1, 2, 4], :time_entry => { :activity_id => 9 }

    assert_response 302
    # check that the issues were updated
    assert_equal [9, 9, 9], TimeEntry.where(:id => [1, 2, 4]).collect {|i| i.activity_id}
  end

  def test_bulk_update_on_different_projects_without_rights
    @request.session[:user_id] = 3
    user = User.find(3)
    action = { :controller => "timelog", :action => "bulk_update" }
    assert user.allowed_to?(action, TimeEntry.find(1).project)
    assert ! user.allowed_to?(action, TimeEntry.find(5).project)
    post :bulk_update, :ids => [1, 5], :time_entry => { :activity_id => 9 }
    assert_response 403
  end

  def test_bulk_update_with_edit_own_time_entries_permission
    @request.session[:user_id] = 2
    Role.find_by_name('Manager').remove_permission! :edit_time_entries
    Role.find_by_name('Manager').add_permission! :edit_own_time_entries
    ids = (0..1).map {TimeEntry.generate!(:user => User.find(2)).id}

    post :bulk_update, :ids => ids, :time_entry => { :activity_id => 9 }
    assert_response 302
  end

  def test_bulk_update_with_edit_own_time_entries_permissions_should_be_denied_for_time_entries_of_other_user
    @request.session[:user_id] = 2
    Role.find_by_name('Manager').remove_permission! :edit_time_entries
    Role.find_by_name('Manager').add_permission! :edit_own_time_entries

    post :bulk_update, :ids => [1, 2], :time_entry => { :activity_id => 9 }
    assert_response 403
  end

  def test_bulk_update_custom_field
    @request.session[:user_id] = 2
    post :bulk_update, :ids => [1, 2], :time_entry => { :custom_field_values => {'10' => '0'} }

    assert_response 302
    assert_equal ["0", "0"], TimeEntry.where(:id => [1, 2]).collect {|i| i.custom_value_for(10).value}
  end

  def test_post_bulk_update_should_redirect_back_using_the_back_url_parameter
    @request.session[:user_id] = 2
    post :bulk_update, :ids => [1,2], :back_url => '/time_entries'

    assert_response :redirect
    assert_redirected_to '/time_entries'
  end

  def test_post_bulk_update_should_not_redirect_back_using_the_back_url_parameter_off_the_host
    @request.session[:user_id] = 2
    post :bulk_update, :ids => [1,2], :back_url => 'http://google.com'

    assert_response :redirect
    assert_redirected_to :controller => 'timelog', :action => 'index', :project_id => Project.find(1).identifier
  end

  def test_post_bulk_update_without_edit_permission_should_be_denied
    @request.session[:user_id] = 2
    Role.find_by_name('Manager').remove_permission! :edit_time_entries
    post :bulk_update, :ids => [1,2]

    assert_response 403
  end

  def test_destroy
    @request.session[:user_id] = 2
    delete :destroy, :id => 1
    assert_redirected_to :action => 'index', :project_id => 'ecookbook'
    assert_equal I18n.t(:notice_successful_delete), flash[:notice]
    assert_nil TimeEntry.find_by_id(1)
  end

  def test_destroy_should_fail
    # simulate that this fails (e.g. due to a plugin), see #5700
    TimeEntry.any_instance.expects(:destroy).returns(false)

    @request.session[:user_id] = 2
    delete :destroy, :id => 1
    assert_redirected_to :action => 'index', :project_id => 'ecookbook'
    assert_equal I18n.t(:notice_unable_delete_time_entry), flash[:error]
    assert_not_nil TimeEntry.find_by_id(1)
  end

  def test_index_all_projects
    get :index
    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:total_hours)
    assert_equal "162.90", "%.2f" % assigns(:total_hours)
    assert_select 'form#query_form[action=?]', '/time_entries'
  end

  def test_index_all_projects_should_show_log_time_link
    @request.session[:user_id] = 2
    get :index
    assert_response :success
    assert_template 'index'
    assert_select 'a[href=?]', '/time_entries/new', :text => /Log time/
  end

  def test_index_my_spent_time
    @request.session[:user_id] = 2
    get :index, :user_id => 'me'
    assert_response :success
    assert_template 'index'
    assert assigns(:entries).all? {|entry| entry.user_id == 2}
  end

  def test_index_at_project_level
    get :index, :project_id => 'ecookbook'
    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:entries)
    assert_equal 4, assigns(:entries).size
    # project and subproject
    assert_equal [1, 3], assigns(:entries).collect(&:project_id).uniq.sort
    assert_not_nil assigns(:total_hours)
    assert_equal "162.90", "%.2f" % assigns(:total_hours)
    assert_select 'form#query_form[action=?]', '/projects/ecookbook/time_entries'
  end

  def test_index_with_display_subprojects_issues_to_false_should_not_include_subproject_entries
    entry = TimeEntry.generate!(:project => Project.find(3))

    with_settings :display_subprojects_issues => '0' do
      get :index, :project_id => 'ecookbook'
      assert_response :success
      assert_template 'index'
      assert_not_include entry, assigns(:entries)
    end
  end

  def test_index_with_display_subprojects_issues_to_false_and_subproject_filter_should_include_subproject_entries
    entry = TimeEntry.generate!(:project => Project.find(3))

    with_settings :display_subprojects_issues => '0' do
      get :index, :project_id => 'ecookbook', :subproject_id => 3
      assert_response :success
      assert_template 'index'
      assert_include entry, assigns(:entries)
    end
  end

  def test_index_at_project_level_with_date_range
    get :index, :project_id => 'ecookbook',
      :f => ['spent_on'],
      :op => {'spent_on' => '><'},
      :v => {'spent_on' => ['2007-03-20', '2007-04-30']}
    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:entries)
    assert_equal 3, assigns(:entries).size
    assert_not_nil assigns(:total_hours)
    assert_equal "12.90", "%.2f" % assigns(:total_hours)
    assert_select 'form#query_form[action=?]', '/projects/ecookbook/time_entries'
  end

  def test_index_at_project_level_with_date_range_using_from_and_to_params
    get :index, :project_id => 'ecookbook', :from => '2007-03-20', :to => '2007-04-30'
    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:entries)
    assert_equal 3, assigns(:entries).size
    assert_not_nil assigns(:total_hours)
    assert_equal "12.90", "%.2f" % assigns(:total_hours)
    assert_select 'form#query_form[action=?]', '/projects/ecookbook/time_entries'
  end

  def test_index_at_project_level_with_period
    get :index, :project_id => 'ecookbook',
      :f => ['spent_on'],
      :op => {'spent_on' => '>t-'},
      :v => {'spent_on' => ['7']}
    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:entries)
    assert_not_nil assigns(:total_hours)
    assert_select 'form#query_form[action=?]', '/projects/ecookbook/time_entries'
  end

  def test_index_at_issue_level
    get :index, :issue_id => 1
    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:entries)
    assert_equal 2, assigns(:entries).size
    assert_not_nil assigns(:total_hours)
    assert_equal 154.25, assigns(:total_hours)
    # display all time
    assert_nil assigns(:from)
    assert_nil assigns(:to)
    assert_select 'form#query_form[action=?]', '/issues/1/time_entries'
  end

  def test_index_should_sort_by_spent_on_and_created_on
    t1 = TimeEntry.create!(:user => User.find(1), :project => Project.find(1), :hours => 1, :spent_on => '2012-06-16', :created_on => '2012-06-16 20:00:00', :activity_id => 10)
    t2 = TimeEntry.create!(:user => User.find(1), :project => Project.find(1), :hours => 1, :spent_on => '2012-06-16', :created_on => '2012-06-16 20:05:00', :activity_id => 10)
    t3 = TimeEntry.create!(:user => User.find(1), :project => Project.find(1), :hours => 1, :spent_on => '2012-06-15', :created_on => '2012-06-16 20:10:00', :activity_id => 10)

    get :index, :project_id => 1,
      :f => ['spent_on'],
      :op => {'spent_on' => '><'},
      :v => {'spent_on' => ['2012-06-15', '2012-06-16']}
    assert_response :success
    assert_equal [t2, t1, t3], assigns(:entries)

    get :index, :project_id => 1,
      :f => ['spent_on'],
      :op => {'spent_on' => '><'},
      :v => {'spent_on' => ['2012-06-15', '2012-06-16']},
      :sort => 'spent_on'
    assert_response :success
    assert_equal [t3, t1, t2], assigns(:entries)
  end

  def test_index_with_filter_on_issue_custom_field
    issue = Issue.generate!(:project_id => 1, :tracker_id => 1, :custom_field_values => {2 => 'filter_on_issue_custom_field'})
    entry = TimeEntry.generate!(:issue => issue, :hours => 2.5)

    get :index, :f => ['issue.cf_2'], :op => {'issue.cf_2' => '='}, :v => {'issue.cf_2' => ['filter_on_issue_custom_field']}
    assert_response :success
    assert_equal [entry], assigns(:entries)
  end

  def test_index_with_issue_custom_field_column
    issue = Issue.generate!(:project_id => 1, :tracker_id => 1, :custom_field_values => {2 => 'filter_on_issue_custom_field'})
    entry = TimeEntry.generate!(:issue => issue, :hours => 2.5)

    get :index, :c => %w(project spent_on issue comments hours issue.cf_2)
    assert_response :success
    assert_include :'issue.cf_2', assigns(:query).column_names
    assert_select 'td.issue_cf_2', :text => 'filter_on_issue_custom_field'
  end

  def test_index_with_time_entry_custom_field_column
    field = TimeEntryCustomField.generate!(:field_format => 'string')
    entry = TimeEntry.generate!(:hours => 2.5, :custom_field_values => {field.id => 'CF Value'})
    field_name = "cf_#{field.id}"

    get :index, :c => ["hours", field_name]
    assert_response :success
    assert_include field_name.to_sym, assigns(:query).column_names
    assert_select "td.#{field_name}", :text => 'CF Value'
  end

  def test_index_with_time_entry_custom_field_sorting
    field = TimeEntryCustomField.generate!(:field_format => 'string', :name => 'String Field')
    TimeEntry.generate!(:hours => 2.5, :custom_field_values => {field.id => 'CF Value 1'})
    TimeEntry.generate!(:hours => 2.5, :custom_field_values => {field.id => 'CF Value 3'})
    TimeEntry.generate!(:hours => 2.5, :custom_field_values => {field.id => 'CF Value 2'})
    field_name = "cf_#{field.id}"

    get :index, :c => ["hours", field_name], :sort => field_name
    assert_response :success
    assert_include field_name.to_sym, assigns(:query).column_names
    assert_select "th a.sort", :text => 'String Field'

    # Make sure that values are properly sorted
    values = assigns(:entries).map {|e| e.custom_field_value(field)}.compact
    assert_equal 3, values.size
    assert_equal values.sort, values
  end

  def test_index_atom_feed
    get :index, :project_id => 1, :format => 'atom'
    assert_response :success
    assert_equal 'application/atom+xml', @response.content_type
    assert_not_nil assigns(:items)
    assert assigns(:items).first.is_a?(TimeEntry)
  end

  def test_index_at_project_level_should_include_csv_export_dialog
    get :index, :project_id => 'ecookbook', 
      :f => ['spent_on'],
      :op => {'spent_on' => '>='},
      :v => {'spent_on' => ['2007-04-01']},
      :c => ['spent_on', 'user']
    assert_response :success

    assert_select '#csv-export-options' do
      assert_select 'form[action=?][method=get]', '/projects/ecookbook/time_entries.csv' do
        # filter
        assert_select 'input[name=?][value=?]', 'f[]', 'spent_on'
        assert_select 'input[name=?][value=?]', 'op[spent_on]', '>='
        assert_select 'input[name=?][value=?]', 'v[spent_on][]', '2007-04-01'
        # columns
        assert_select 'input[name=?][value=?]', 'c[]', 'spent_on'
        assert_select 'input[name=?][value=?]', 'c[]', 'user'
        assert_select 'input[name=?]', 'c[]', 2
      end
    end
  end

  def test_index_cross_project_should_include_csv_export_dialog
    get :index
    assert_response :success

    assert_select '#csv-export-options' do
      assert_select 'form[action=?][method=get]', '/time_entries.csv'
    end
  end

  def test_index_at_issue_level_should_include_csv_export_dialog
    get :index, :issue_id => 3
    assert_response :success

    assert_select '#csv-export-options' do
      assert_select 'form[action=?][method=get]', '/issues/3/time_entries.csv'
    end
  end

  def test_index_csv_all_projects
    with_settings :date_format => '%m/%d/%Y' do
      get :index, :format => 'csv'
      assert_response :success
      assert_equal 'text/csv; header=present', response.content_type
    end
  end

  def test_index_csv
    with_settings :date_format => '%m/%d/%Y' do
      get :index, :project_id => 1, :format => 'csv'
      assert_response :success
      assert_equal 'text/csv; header=present', response.content_type
    end
  end

  def test_index_csv_should_fill_issue_column_with_tracker_id_and_subject
    issue = Issue.find(1)
    entry = TimeEntry.generate!(:issue => issue, :comments => "Issue column content test")

    get :index, :format => 'csv'
    line = response.body.split("\n").detect {|l| l.include?(entry.comments)}
    assert_not_nil line
    assert_include "#{issue.tracker} #1: #{issue.subject}", line
  end
end
