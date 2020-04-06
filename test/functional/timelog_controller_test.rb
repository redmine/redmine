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

class TimelogControllerTest < Redmine::ControllerTest
  fixtures :projects, :enabled_modules, :roles, :members,
           :member_roles, :issues, :time_entries, :users,
           :trackers, :enumerations, :issue_statuses,
           :custom_fields, :custom_values,
           :projects_trackers, :custom_fields_trackers,
           :custom_fields_projects, :issue_categories, :versions

  include Redmine::I18n

  def setup
    super
    Setting.default_language = 'en'
  end

  def test_new
    @request.session[:user_id] = 3
    get :new
    assert_response :success

    assert_select 'input[name=?][type=hidden]', 'project_id', 0
    assert_select 'input[name=?][type=hidden]', 'issue_id', 0
    assert_select 'span[id=?]', 'time_entry_issue'
    assert_select 'select[name=?]', 'time_entry[project_id]' do
      # blank option for project
      assert_select 'option[value=""]'
    end
    assert_select 'label[for=?]', 'time_entry_user_id', 0
    assert_select 'select[name=?]', 'time_entry[user_id]', 0
  end

  def test_new_with_project_id
    @request.session[:user_id] = 3
    get :new, :params => {:project_id => 1}
    assert_response :success

    assert_select 'input[name=?][type=hidden]', 'project_id'
    assert_select 'input[name=?][type=hidden]', 'issue_id', 0
    assert_select 'select[name=?]', 'time_entry[project_id]', 0
  end

  def test_new_with_issue_id
    @request.session[:user_id] = 3
    get :new, :params => {:issue_id => 2}
    assert_response :success

    assert_select 'input[name=?][type=hidden]', 'project_id', 0
    assert_select 'input[name=?][type=hidden]', 'issue_id'
    assert_select 'a[href=?]', '/issues/2', :text => /Feature request #2/
    assert_select 'select[name=?]', 'time_entry[project_id]', 0
  end

  def test_new_without_project_should_prefill_the_form
    @request.session[:user_id] = 3
    get :new, :params => {:time_entry => {:project_id => '1'}}
    assert_response :success

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
    get :new, :params => {:project_id => 1}
    assert_response :success
    assert_select 'select[name=?]', 'time_entry[activity_id]' do
      assert_select 'option[selected=selected]', :text => 'Development'
    end
  end

  def test_new_should_only_show_active_time_entry_activities
    @request.session[:user_id] = 3
    get :new, :params => {:project_id => 1}
    assert_response :success
    assert_select 'option', :text => 'Inactive Activity', :count => 0
  end

  def test_new_should_show_user_select_if_user_has_permission
    Role.find_by_name('Manager').add_permission! :log_time_for_other_users
    @request.session[:user_id] = 2

    get :new, :params => {:project_id => 1}
    assert_response :success
    assert_select 'select[name=?]', 'time_entry[user_id]' do
      assert_select 'option', 3
      assert_select 'option[value=?]', '2', 2
      assert_select 'option[value=?]', '3', 1
      # locked members should not be available
      assert_select 'option[value=?]', '4', 0
    end
  end

  def test_new_user_select_should_include_current_user_if_is_logged
    @request.session[:user_id] = 1

    get :new, :params => {:project_id => 1}
    assert_response :success
    assert_select 'select[name=?]', 'time_entry[user_id]' do
      assert_select 'option[value=?]', '1', :text => '<< me >>'
      assert_select 'option[value=?]', '1', :text => 'Redmine Admin'
    end
  end

  def test_new_should_not_show_user_select_if_user_does_not_have_permission
    @request.session[:user_id] = 2

    get :new, :params => {:project_id => 1}
    assert_response :success
    assert_select 'select[name=?]', 'time_entry[user_id]', 0
  end

  def test_post_new_as_js_should_update_activity_options
    @request.session[:user_id] = 3
    post :new, :params => {:time_entry => {:project_id => 1}, :format => 'js'}
    assert_response :success
    assert_include '#time_entry_activity_id', response.body
  end

  def test_get_edit_existing_time
    @request.session[:user_id] = 2
    get :edit, :params => {:id => 2, :project_id => nil}
    assert_response :success

    assert_select 'form[action=?]', '/time_entries/2'

    # Time entry user should be shown as text
    # for user without permission to log time for other users
    assert_select 'label[for=?]', 'time_entry_user_id', 1
    assert_select 'a.user.active', :text => 'Redmine Admin'
  end

  def test_get_edit_with_an_existing_time_entry_with_inactive_activity
    te = TimeEntry.find(1)
    te.activity = TimeEntryActivity.find_by_name("Inactive Activity")
    te.save!(:validate => false)

    @request.session[:user_id] = 1
    get :edit, :params => {:project_id => 1, :id => 1}
    assert_response :success

    # Blank option since nothing is pre-selected
    assert_select 'option', :text => '--- Please select ---'
  end

  def test_get_edit_should_show_projects_select
    @request.session[:user_id] = 2
    get :edit, :params => {:id => 2, :project_id => nil}
    assert_response :success

    assert_select 'select[name=?]', 'time_entry[project_id]'
  end

  def test_get_edit_should_validate_back_url
    @request.session[:user_id] = 2

    get :edit, :params => {:id => 2, :project_id => nil, :back_url => '/valid'}
    assert_response :success
    assert_select 'a[href=?]', '/valid', {:text => 'Cancel'}

    get :edit, :params => {:id => 2, :project_id => nil, :back_url => 'invalid'}
    assert_response :success
    assert_select 'a[href=?]', 'invalid', {:text => 'Cancel', :count => 0}
    assert_select 'a[href=?]', '/projects/ecookbook/time_entries', {:text => 'Cancel'}
  end

  def test_get_edit_with_an_existing_time_entry_with_locked_user
    user = User.find(3)
    entry = TimeEntry.generate!(:user_id => user.id, :comments => "Time entry on a future locked user")
    entry.save!

    user.status = User::STATUS_LOCKED
    user.save!
    Role.find_by_name('Manager').add_permission! :log_time_for_other_users
    @request.session[:user_id] = 2

    get :edit, :params => {
      :id => entry.id
    }

    assert_response :success

    assert_select 'select[name=?]', 'time_entry[user_id]' do
      # User with id 3 should be selected even if it's locked
      assert_select 'option[value="3"][selected=selected]'
    end
  end

  def test_get_edit_for_other_user
    Role.find_by_name('Manager').add_permission! :log_time_for_other_users
    @request.session[:user_id] = 2

    get :edit, :params => {
      :id => 1
    }

    assert_response :success

    assert_select 'select[name=?]', 'time_entry[user_id]' do
      assert_select 'option[value="2"][selected=selected]'
    end
  end

  def test_post_create
    @request.session[:user_id] = 3
    assert_difference 'TimeEntry.count' do
      post :create, :params => {
        :project_id => 1,
        :time_entry => {:comments => 'Some work on TimelogControllerTest',
          # Not the default activity
          :activity_id => '11',
          :spent_on => '2008-03-14',
          :issue_id => '1',
          :hours => '7.3'
        }
      }
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
      post :create, :params => {
        :project_id => 1,
        :time_entry => {
          :comments => 'Some work on TimelogControllerTest',
          # Not the default activity
          :activity_id => '11',
          :issue_id => '',
          :spent_on => '2008-03-14',
          :hours => '7.3'
        }
      }
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
      post :create, :params => {
        :time_entry => {
          :project_id => '1', :issue_id => '',
          :activity_id => '11', :spent_on => '2008-03-14', :hours => '7.3'
        }
      }
    end
  end

  def test_create_on_project_without_permission_should_fail
    Role.find(1).remove_permission! :log_time

    @request.session[:user_id] = 2
    assert_no_difference 'TimeEntry.count' do
      post :create, :params => {
        :time_entry => {
          :project_id => '1', :issue_id => '',
          :activity_id => '11', :spent_on => '2008-03-14', :hours => '7.3'
        }
      }
    end
  end

  def test_create_on_issue_in_project_with_time_tracking_disabled_should_fail
    Project.find(1).disable_module! :time_tracking

    @request.session[:user_id] = 2
    assert_no_difference 'TimeEntry.count' do
      post :create, :params => {
        :time_entry => {
          :project_id => '', :issue_id => '1',
          :activity_id => '11', :spent_on => '2008-03-14', :hours => '7.3'
        }
      }
      assert_select_error /Issue is invalid/
    end
  end

  def test_create_on_issue_in_project_without_permission_should_fail
    Role.find(1).remove_permission! :log_time

    @request.session[:user_id] = 2
    assert_no_difference 'TimeEntry.count' do
      post :create, :params => {
        :time_entry => {
          :project_id => '', :issue_id => '1',
          :activity_id => '11', :spent_on => '2008-03-14', :hours => '7.3'
        }
      }
      assert_select_error /Issue is invalid/
    end
  end

  def test_create_on_issue_that_is_not_visible_should_not_disclose_subject
    issue = Issue.generate!(:subject => "issue_that_is_not_visible", :is_private => true)
    assert !issue.visible?(User.find(3))

    @request.session[:user_id] = 3
    assert_no_difference 'TimeEntry.count' do
      post :create, :params => {
        :time_entry => {
          :project_id => '', :issue_id => issue.id.to_s,
          :activity_id => '11', :spent_on => '2008-03-14', :hours => '7.3'
        }
      }
    end
    assert_select_error /Issue is invalid/
    assert_select "input[name=?][value=?]", "time_entry[issue_id]", issue.id.to_s
    assert_select "#time_entry_issue a", 0
    assert !response.body.include?('issue_that_is_not_visible')
  end

  def test_create_for_other_user
    Role.find_by_name('Manager').add_permission! :log_time_for_other_users
    @request.session[:user_id] = 2

    post :create, :params => {
      :project_id => 1,
      :time_entry => {:comments => 'Some work on TimelogControllerTest',
        # Not the default activity
        :activity_id => '11',
        :spent_on => '2008-03-14',
        :issue_id => '1',
        :hours => '7.3',
        :user_id => '3'
      }
    }

    assert_redirected_to '/projects/ecookbook/time_entries'

    t = TimeEntry.last
    assert_equal 3, t.user_id
    assert_equal 2, t.author_id
  end

  def test_create_for_other_user_should_fail_without_permission
    Role.find_by_name('Manager').remove_permission! :log_time_for_other_users
    @request.session[:user_id] = 2

    post :create, :params => {
      :project_id => 1,
      :time_entry => {:comments => 'Some work on TimelogControllerTest',
        # Not the default activity
        :activity_id => '11',
        :spent_on => '2008-03-14',
        :issue_id => '1',
        :hours => '7.3',
        :user_id => '3'
      }
    }

    assert_response :success
    assert_select_error /User is invalid/
  end

  def test_create_and_continue_at_project_level
    @request.session[:user_id] = 2
    assert_difference 'TimeEntry.count' do
      post :create, :params => {
        :time_entry => {
          :project_id => '1',
          :activity_id => '11',
          :issue_id => '',
          :spent_on => '2008-03-14',
          :hours => '7.3'
        },
        :continue => '1'
      }
      assert_redirected_to '/time_entries/new?time_entry%5Bactivity_id%5D=11&time_entry%5Bissue_id%5D=&time_entry%5Bproject_id%5D=1&time_entry%5Bspent_on%5D=2008-03-14'
    end
  end

  def test_create_and_continue_at_issue_level
    @request.session[:user_id] = 2
    assert_difference 'TimeEntry.count' do
      post :create, :params => {
        :time_entry => {
          :project_id => '',
          :activity_id => '11',
          :issue_id => '1',
          :spent_on => '2008-03-14',
          :hours => '7.3'
        },
        :continue => '1'
      }
      assert_redirected_to '/time_entries/new?time_entry%5Bactivity_id%5D=11&time_entry%5Bissue_id%5D=1&time_entry%5Bproject_id%5D=&time_entry%5Bspent_on%5D=2008-03-14'
    end
  end

  def test_create_and_continue_with_project_id
    @request.session[:user_id] = 2
    assert_difference 'TimeEntry.count' do
      post :create, :params => {
        :project_id => 1,
        :time_entry => {
          :activity_id => '11',
          :issue_id => '',
          :spent_on => '2008-03-14',
          :hours => '7.3'
        },
        :continue => '1'
      }
      assert_redirected_to '/projects/ecookbook/time_entries/new?time_entry%5Bactivity_id%5D=11&time_entry%5Bissue_id%5D=&time_entry%5Bproject_id%5D=&time_entry%5Bspent_on%5D=2008-03-14'
    end
  end

  def test_create_and_continue_with_issue_id
    @request.session[:user_id] = 2
    assert_difference 'TimeEntry.count' do
      post :create, :params => {
        :issue_id => 1,
        :time_entry => {
          :activity_id => '11',
          :issue_id => '1',
          :spent_on => '2008-03-14',
          :hours => '7.3'
        },
        :continue => '1'
      }
      assert_redirected_to '/issues/1/time_entries/new?time_entry%5Bactivity_id%5D=11&time_entry%5Bissue_id%5D=1&time_entry%5Bproject_id%5D=&time_entry%5Bspent_on%5D=2008-03-14'
    end
  end

  def test_create_without_log_time_permission_should_be_denied
    @request.session[:user_id] = 2
    Role.find_by_name('Manager').remove_permission! :log_time
    post :create, :params => {
      :project_id => 1,
      :time_entry => {
        :activity_id => '11',
        :issue_id => '',
        :spent_on => '2008-03-14',
        :hours => '7.3'
      }
    }
    assert_response 403
  end

  def test_create_without_project_and_issue_should_fail
    @request.session[:user_id] = 2
    post :create, :params => {:time_entry => {:issue_id => ''}}

    assert_response :success
    assert_select_error /Project cannot be blank/
  end

  def test_create_with_failure
    @request.session[:user_id] = 2
    post :create, :params => {
      :project_id => 1,
      :time_entry => {
        :activity_id => '',
        :issue_id => '',
        :spent_on => '2008-03-14',
        :hours => '7.3'
      }
    }
    assert_response :success
  end

  def test_create_without_project
    @request.session[:user_id] = 2
    assert_difference 'TimeEntry.count' do
      post :create, :params => {
        :time_entry => {
          :project_id => '1',
          :activity_id => '11',
          :issue_id => '',
          :spent_on => '2008-03-14',
          :hours => '7.3'
        }
      }
    end

    assert_redirected_to '/projects/ecookbook/time_entries'
    time_entry = TimeEntry.order('id DESC').first
    assert_equal 1, time_entry.project_id
  end

  def test_create_without_project_should_fail_with_issue_not_inside_project
    @request.session[:user_id] = 2
    assert_no_difference 'TimeEntry.count' do
      post :create, :params => {
        :time_entry => {
          :project_id => '1',
          :activity_id => '11',
          :issue_id => '5',
          :spent_on => '2008-03-14',
          :hours => '7.3'
        }
      }
    end

    assert_response :success
    assert_select_error /Issue is invalid/
  end

  def test_create_without_project_should_deny_without_permission
    @request.session[:user_id] = 2
    Project.find(3).disable_module!(:time_tracking)

    assert_no_difference 'TimeEntry.count' do
      post :create, :params => {
        :time_entry => {
          :project_id => '3',
          :activity_id => '11',
          :issue_id => '',
          :spent_on => '2008-03-14',
          :hours => '7.3'
        }
      }
    end

    assert_response 403
  end

  def test_create_without_project_with_failure
    @request.session[:user_id] = 2
    assert_no_difference 'TimeEntry.count' do
      post :create, :params => {
        :time_entry => {
          :project_id => '1',
          :activity_id => '11',
          :issue_id => '',
          :spent_on => '2008-03-14',
          :hours => ''
        }
      }
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
    put :update, :params => {
      :id => 1,
      :time_entry => {
        :issue_id => '2',
        :hours => '8'
      }
    }
    assert_redirected_to :action => 'index', :project_id => 'ecookbook'
    entry.reload

    assert_equal 8, entry.hours
    assert_equal 2, entry.issue_id
    assert_equal 2, entry.user_id
  end

  def test_update_should_allow_to_change_issue_to_another_project
    entry = TimeEntry.generate!(:issue_id => 1)

    @request.session[:user_id] = 1
    put :update, :params => {
      :id => entry.id,
      :time_entry => {
        :issue_id => '5'
      }
    }
    assert_response 302
    entry.reload

    assert_equal 5, entry.issue_id
    assert_equal 3, entry.project_id
  end

  def test_update_should_not_allow_to_change_issue_to_an_invalid_project
    entry = TimeEntry.generate!(:issue_id => 1)
    Project.find(3).disable_module!(:time_tracking)

    @request.session[:user_id] = 1
    put :update, :params => {
      :id => entry.id,
      :time_entry => {
        :issue_id => '5'
      }
    }
    assert_response :success
    assert_select_error /Issue is invalid/
  end

  def test_update_should_allow_to_change_project
    entry = TimeEntry.generate!(:project_id => 1)

    @request.session[:user_id] = 1
    put :update, :params => {
      :id => entry.id,
      :time_entry => {
        :project_id => '2'
      }
    }
    assert_response 302
    entry.reload

    assert_equal 2, entry.project_id
  end

  def test_update_should_fail_with_issue_from_another_project
    entry = TimeEntry.generate!(:project_id => 1, :issue_id => 1)

    @request.session[:user_id] = 1
    put :update, :params => {
      :id => entry.id,
      :time_entry => {
        :project_id => '2'
      }
    }

    assert_response :success
    assert_select_error /Issue is invalid/
  end

  def test_update_should_fail_when_changing_user_without_permission
    Role.find_by_name('Manager').remove_permission! :log_time_for_other_users
    @request.session[:user_id] = 2

    put :update, :params => {
      :id => 3,
      :time_entry => {
        :user_id => '3'
      }
    }

    assert_response :success
    assert_select_error /User is invalid/
  end

  def test_update_should_allow_updating_existing_entry_logged_on_a_locked_user
    entry = TimeEntry.generate!(:user_id => 2, :hours => 4, :comments => "Time entry on a future locked user")
    Role.find_by_name('Manager').add_permission! :log_time_for_other_users
    @request.session[:user_id] = 2

    put :update, :params => {
      :id => entry.id,
      :time_entry => {
        :hours => '6'
      }
    }

    assert_response :redirect

    entry.reload
    # Ensure user didn't change
    assert_equal 2, entry.user_id
    assert_equal 6.0, entry.hours
  end

  def test_get_bulk_edit
    @request.session[:user_id] = 2

    get :bulk_edit, :params => {:ids => [1, 2]}
    assert_response :success

    assert_select 'ul#bulk-selection' do
      assert_select 'li', 2
      assert_select 'li a', :text => '03/23/2007 - eCookbook: 4.25 hours (John Smith)'
    end

    assert_select 'form#bulk_edit_form[action=?]', '/time_entries/bulk_update' do
      assert_select 'select[name=?]', 'time_entry[project_id]'

      # Clear issue checkbox
      assert_select 'input[name=?][value=?]', 'time_entry[issue_id]', 'none'

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

    get :bulk_edit, :params => {:ids => [1, 2, 6]}
    assert_response :success
  end

  def test_get_bulk_edit_on_different_projects_should_propose_only_common_activites
    project = Project.find(3)
    TimeEntryActivity.create!(:name => 'QA', :project => project, :parent => TimeEntryActivity.find_by_name('QA'), :active => false)
    @request.session[:user_id] = 1

    get :bulk_edit, :params => {:ids => [1, 2, 4]}
    assert_response :success
    assert_select 'select[id=?]', 'time_entry_activity_id' do
      assert_select 'option', 3
      assert_select 'option[value=?]', '11', 0, :text => 'QA'
    end
  end

  def test_get_bulk_edit_on_same_project_should_propose_project_activities
    project = Project.find(1)
    override_activity = TimeEntryActivity.create!({:name => "QA override", :parent => TimeEntryActivity.find_by_name("QA"), :project => project})

    @request.session[:user_id] = 1

    get :bulk_edit, :params => {:ids => [1, 2]}
    assert_response :success

    assert_select 'select[id=?]', 'time_entry_activity_id' do
      assert_select 'option', 4
      assert_select 'option[value=?]', override_activity.id.to_s, :text => 'QA override'
    end
  end

  def test_bulk_edit_with_edit_own_time_entries_permission
    @request.session[:user_id] = 2
    Role.find_by_name('Manager').remove_permission! :edit_time_entries
    Role.find_by_name('Manager').add_permission! :edit_own_time_entries
    ids = (0..1).map {TimeEntry.generate!(:user => User.find(2)).id}

    get :bulk_edit, :params => {:ids => ids}
    assert_response :success
  end

  def test_bulk_update
    @request.session[:user_id] = 2
    # update time entry activity
    post :bulk_update, :params => {:ids => [1, 2], :time_entry => { :activity_id => 9}}

    assert_response 302
    # check that the issues were updated
    assert_equal [9, 9], TimeEntry.where(:id => [1, 2]).collect {|i| i.activity_id}
  end

  def test_bulk_update_with_failure
    @request.session[:user_id] = 2
    post :bulk_update, :params => {:ids => [1, 2], :time_entry => { :hours => 'A'}}

    assert_response :success
    assert_select_error /Failed to save 2 time entrie/
  end

  def test_bulk_update_on_different_projects
    @request.session[:user_id] = 2
    # makes user a manager on the other project
    Member.create!(:user_id => 2, :project_id => 3, :role_ids => [1])

    # update time entry activity
    post :bulk_update, :params => {:ids => [1, 2, 4], :time_entry => { :activity_id => 9 }}

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

    post :bulk_update, :params => {:ids => [1, 5], :time_entry => { :activity_id => 9 }}
    assert_response 403
  end

  def test_bulk_update_with_edit_own_time_entries_permission
    @request.session[:user_id] = 2
    Role.find_by_name('Manager').remove_permission! :edit_time_entries
    Role.find_by_name('Manager').add_permission! :edit_own_time_entries
    ids = (0..1).map {TimeEntry.generate!(:user => User.find(2)).id}

    post :bulk_update, :params => {:ids => ids, :time_entry => { :activity_id => 9 }}
    assert_response 302
  end

  def test_bulk_update_with_edit_own_time_entries_permissions_should_be_denied_for_time_entries_of_other_user
    @request.session[:user_id] = 2
    Role.find_by_name('Manager').remove_permission! :edit_time_entries
    Role.find_by_name('Manager').add_permission! :edit_own_time_entries

    post :bulk_update, :params => {:ids => [1, 2], :time_entry => { :activity_id => 9 }}
    assert_response 403
  end

  def test_bulk_update_custom_field
    @request.session[:user_id] = 2
    post :bulk_update, :params => {:ids => [1, 2], :time_entry => { :custom_field_values => {'10' => '0'} }}

    assert_response 302
    assert_equal ["0", "0"], TimeEntry.where(:id => [1, 2]).collect {|i| i.custom_value_for(10).value}
  end

  def test_bulk_update_clear_custom_field
    field = TimeEntryCustomField.generate!(:field_format => 'string')
    @request.session[:user_id] = 2
    post :bulk_update, :params => {:ids => [1, 2], :time_entry => { :custom_field_values => {field.id.to_s => '__none__'} }}

    assert_response 302
    assert_equal ["", ""], TimeEntry.where(:id => [1, 2]).collect {|i| i.custom_value_for(field).value}
  end

  def test_post_bulk_update_should_redirect_back_using_the_back_url_parameter
    @request.session[:user_id] = 2
    post :bulk_update, :params => {:ids => [1,2], :back_url => '/time_entries'}

    assert_response :redirect
    assert_redirected_to '/time_entries'
  end

  def test_post_bulk_update_should_not_redirect_back_using_the_back_url_parameter_off_the_host
    @request.session[:user_id] = 2
    post :bulk_update, :params => {:ids => [1,2], :back_url => 'http://google.com'}

    assert_response :redirect
    assert_redirected_to :controller => 'timelog', :action => 'index', :project_id => Project.find(1).identifier
  end

  def test_post_bulk_update_without_edit_permission_should_be_denied
    @request.session[:user_id] = 2
    Role.find_by_name('Manager').remove_permission! :edit_time_entries

    post :bulk_update, :params => {:ids => [1,2]}
    assert_response 403
  end

  def test_destroy
    @request.session[:user_id] = 2

    delete :destroy, :params => {:id => 1}
    assert_redirected_to :action => 'index', :project_id => 'ecookbook'
    assert_equal I18n.t(:notice_successful_delete), flash[:notice]
    assert_nil TimeEntry.find_by_id(1)
  end

  def test_destroy_should_fail
    # simulate that this fails (e.g. due to a plugin), see #5700
    TimeEntry.any_instance.expects(:destroy).returns(false)
    @request.session[:user_id] = 2

    delete :destroy, :params => {:id => 1}
    assert_redirected_to :action => 'index', :project_id => 'ecookbook'
    assert_equal I18n.t(:notice_unable_delete_time_entry), flash[:error]
    assert_not_nil TimeEntry.find_by_id(1)
  end

  def test_destroy_should_redirect_to_referer
    referer = 'http://test.host/time_entries?utf8=✓&set_filter=1&&f%5B%5D=user_id&op%5Buser_id%5D=%3D&v%5Buser_id%5D%5B%5D=me'
    @request.env["HTTP_REFERER"] = referer
    @request.session[:user_id] = 2

    delete :destroy, :params => {:id => 1}
    assert_redirected_to referer
  end

  def test_index_all_projects
    get :index
    assert_response :success

    assert_select '.total-for-hours', :text => 'Hours: 162.90'
    assert_select 'form#query_form[action=?]', '/time_entries'

    assert_equal ['Project', 'Date', 'User', 'Activity', 'Issue', 'Comment', 'Hours'], columns_in_list
    assert_select '.query-totals>span', 1
  end

  def test_index_with_default_query_setting
    with_settings :time_entry_list_defaults => {'column_names' => %w(spent_on issue user hours), 'totalable_names' => []} do
      get :index
      assert_response :success
    end

    assert_select 'table.time-entries thead' do
      assert_select 'th.project'
      assert_select 'th.spent_on'
      assert_select 'th.issue'
      assert_select 'th.user'
      assert_select 'th.hours'
    end
    assert_select 'table.time-entries tbody' do
      assert_select 'td.project'
      assert_select 'td.spent_on'
      assert_select 'td.issue'
      assert_select 'td.user'
      assert_select 'td.hours'
    end
    assert_equal ['Project', 'Date', 'Issue', 'User', 'Hours'], columns_in_list
  end

  def test_index_with_default_query_setting_using_custom_field
    field = TimeEntryCustomField.create!(:name => 'Foo', :field_format => 'int')

    with_settings :time_entry_list_defaults => {
        'column_names' => ["spent_on", "user", "hours", "cf_#{field.id}"],
        'totalable_names' => ["hours", "cf_#{field.id}"]
      } do
      get :index
      assert_response :success
    end

    assert_equal ['Project', 'Date', 'User', 'Hours', 'Foo'], columns_in_list

    assert_select '.total-for-hours'
    assert_select ".total-for-cf-#{field.id}"
    assert_select '.query-totals>span', 2
  end

  def test_index_all_projects_should_show_log_time_link
    @request.session[:user_id] = 2
    get :index
    assert_response :success

    assert_select 'a[href=?]', '/time_entries/new', :text => /Log time/
  end

  def test_index_my_spent_time
    @request.session[:user_id] = 2
    get :index, :params => {:user_id => 'me', :c => ['user']}
    assert_response :success

    users = css_select('table.time-entries tbody td.user').map(&:text).uniq
    assert_equal ["John Smith"], users
  end

  def test_index_at_project_level
    @request.session[:user_id] = 2

    get :index, :params => {:project_id => 'ecookbook', :c => ['project']}
    assert_response :success

    assert_select 'tr.time-entry', 4

    # project and subproject
    projects = css_select('table.time-entries tbody td.project').map(&:text).uniq.sort
    assert_equal ["eCookbook", "eCookbook Subproject 1"], projects

    assert_select '.total-for-hours', :text => 'Hours: 162.90'
    assert_select 'form#query_form[action=?]', '/projects/ecookbook/time_entries'

    # 'Log time' shoudl link to log time on the filtered issue
    assert_select 'a[href=?]', "/projects/ecookbook/time_entries/new"
  end

  def test_index_with_display_subprojects_issues_to_false_should_not_include_subproject_entries
    entry = TimeEntry.generate!(:project => Project.find(3))

    with_settings :display_subprojects_issues => '0' do
      get :index, :params => {:project_id => 'ecookbook', :c => ['project']}
      assert_response :success

      projects = css_select('table.time-entries tbody td.project').map(&:text).uniq.sort
      assert_equal ["eCookbook"], projects
    end
  end

  def test_index_with_display_subprojects_issues_to_false_and_subproject_filter_should_include_subproject_entries
    entry = TimeEntry.generate!(:project => Project.find(3))

    with_settings :display_subprojects_issues => '0' do
      get :index, :params => {:project_id => 'ecookbook', :c => ['project'], :subproject_id => 3}
      assert_response :success

      projects = css_select('table.time-entries tbody td.project').map(&:text).uniq.sort
      assert_equal ["eCookbook", "eCookbook Subproject 1"], projects
    end
  end

  def test_index_at_project_level_with_issue_id_short_filter
    issue = Issue.generate!(:project_id => 1)
    TimeEntry.generate!(:issue => issue, :hours => 4)
    TimeEntry.generate!(:issue => issue, :hours => 3)
    @request.session[:user_id] = 2

    get :index, :params => {:project_id => 'ecookbook', :issue_id => issue.id.to_s, :set_filter => 1}
    assert_select '.total-for-hours', :text => 'Hours: 7.00'

    # 'Log time' shoudl link to log time on the filtered issue
    assert_select 'a[href=?]', "/issues/#{issue.id}/time_entries/new"
  end

  def test_index_at_project_level_with_issue_fixed_version_id_short_filter
    version = Version.generate!(:project_id => 1)
    issue = Issue.generate!(:project_id => 1, :fixed_version => version)
    TimeEntry.generate!(:issue => issue, :hours => 2)
    TimeEntry.generate!(:issue => issue, :hours => 3)
    @request.session[:user_id] = 2

    get :index, :params => {:project_id => 'ecookbook', :"issue.fixed_version_id" => version.id.to_s, :set_filter => 1}
    assert_select '.total-for-hours', :text => 'Hours: 5.00'
  end

  def test_index_at_project_level_with_multiple_issue_fixed_version_ids
    version = Version.generate!(:project_id => 1)
    version2 = Version.generate!(:project_id => 1)
    issue = Issue.generate!(:project_id => 1, :fixed_version => version)
    issue2 = Issue.generate!(:project_id => 1, :fixed_version => version2)
    TimeEntry.generate!(:issue => issue, :hours => 2)
    TimeEntry.generate!(:issue => issue2, :hours => 3)
    @request.session[:user_id] = 2

    get :index, :params => {
      :project_id => 'ecookbook',
      :f => ['issue.fixed_version_id'],
      :op => {'issue.fixed_version_id' => '='},
      :v => {'issue.fixed_version_id' => [version.id.to_s,version2.id.to_s]}
    }
    assert_response :success

    assert_select 'tr.time-entry', 2
    assert_select '.total-for-hours', :text => 'Hours: 5.00'
  end

  def test_index_at_project_level_with_date_range
    get :index, :params => {
      :project_id => 'ecookbook',
      :f => ['spent_on'],
      :op => {'spent_on' => '><'},
      :v => {'spent_on' => ['2007-03-20', '2007-04-30']}
    }
    assert_response :success

    assert_select 'tr.time-entry', 3
    assert_select '.total-for-hours', :text => 'Hours: 12.90'
    assert_select 'form#query_form[action=?]', '/projects/ecookbook/time_entries'
  end

  def test_index_at_project_level_with_date_range_using_from_and_to_params
    get :index, :params => {
      :project_id => 'ecookbook',
      :from => '2007-03-20',
      :to => '2007-04-30'
    }
    assert_response :success

    assert_select 'tr.time-entry', 3
    assert_select '.total-for-hours', :text => 'Hours: 12.90'
    assert_select 'form#query_form[action=?]', '/projects/ecookbook/time_entries'
  end

  def test_index_at_project_level_with_period
    get :index, :params => {
      :project_id => 'ecookbook',
      :f => ['spent_on'],
      :op => {'spent_on' => '>t-'},
      :v => {'spent_on' => ['7']}
    }
    assert_response :success

    assert_select 'form#query_form[action=?]', '/projects/ecookbook/time_entries'
  end

  def test_index_should_sort_by_spent_on_and_created_on
    t1 = TimeEntry.create!(:author => User.find(1), :user => User.find(1), :project => Project.find(1), :hours => 1, :spent_on => '2012-06-16', :created_on => '2012-06-16 20:00:00', :activity_id => 10)
    t2 = TimeEntry.create!(:author => User.find(1), :user => User.find(1), :project => Project.find(1), :hours => 1, :spent_on => '2012-06-16', :created_on => '2012-06-16 20:05:00', :activity_id => 10)
    t3 = TimeEntry.create!(:author => User.find(1), :user => User.find(1), :project => Project.find(1), :hours => 1, :spent_on => '2012-06-15', :created_on => '2012-06-16 20:10:00', :activity_id => 10)

    get :index, :params => {
      :project_id => 1,
      :f => ['spent_on'],
      :op => {'spent_on' => '><'},
      :v => {'spent_on' => ['2012-06-15', '2012-06-16']}
    }
    assert_response :success
    assert_equal [t2, t1, t3].map(&:id).map(&:to_s), css_select('input[name="ids[]"]').map {|e| e.attr('value')}

    get :index, :params => {
      :project_id => 1,
      :f => ['spent_on'],
      :op => {'spent_on' => '><'},
      :v => {'spent_on' => ['2012-06-15', '2012-06-16']},
      :sort => 'spent_on'
    }
    assert_response :success
    assert_equal [t3, t1, t2].map(&:id).map(&:to_s), css_select('input[name="ids[]"]').map {|e| e.attr('value')}
  end

  def test_index_with_activity_filter
    activity = TimeEntryActivity.create!(:name => 'Activity')
    entry = TimeEntry.generate!(:issue_id => 1, :hours => 4.5, :activity => activity)

    get :index, :params => {
      :f => ['activity_id'],
      :op => {'activity_id' => '='},
      :v => {'activity_id' => [activity.id.to_s]}
    }
    assert_response :success
    assert_select "tr#time-entry-#{entry.id}"
    assert_select "table.time-entries tbody tr", 1
  end

  def test_index_with_issue_status_filter
    Issue.where(:status_id => 4).update_all(:status_id => 2)
    issue = Issue.generate!(:project_id => 1, :tracker_id => 1, :status_id => 4)
    entry = TimeEntry.generate!(:issue => issue, :hours => 4.5)

    get :index, :params => {
      :f => ['issue.status_id'],
      :op => {'issue.status_id' => '='},
      :v => {'issue.status_id' => ['4']}
    }
    assert_response :success
    assert_equal [entry].map(&:id).map(&:to_s), css_select('input[name="ids[]"]').map {|e| e.attr('value')}
  end

  def test_index_with_project_status_filter
    project = Project.find(3)
    project.close
    project.save

    get :index, :params => {
        :set_filter => 1,
        :f => ['project.status'],
        :op => {'project.status' => '='},
        :v => {'project.status' => ['1']}
    }

    assert_response :success

    time_entries = css_select('input[name="ids[]"]').map {|e| e.attr('value')}
    assert_include '1', time_entries
    assert_not_include '4', time_entries
  end

  def test_index_with_issue_status_column
    issue = Issue.generate!(:project_id => 1, :tracker_id => 1, :status_id => 4)
    entry = TimeEntry.generate!(:issue => issue)

    get :index, :params => {
      :c => %w(project spent_on issue comments hours issue.status)
    }
    assert_response :success

    assert_select 'th.issue-status'
    assert_select 'td.issue-status', :text => issue.status.name
  end

  def test_index_with_issue_status_sort
    TimeEntry.delete_all
    TimeEntry.generate!(:issue => Issue.generate!(:project_id => 1, :tracker_id => 1, :status_id => 1))
    TimeEntry.generate!(:issue => Issue.generate!(:project_id => 1, :tracker_id => 1, :status_id => 5))
    TimeEntry.generate!(:issue => Issue.generate!(:project_id => 1, :tracker_id => 1, :status_id => 3))
    TimeEntry.generate!(:project_id => 1)

    get :index, :params => {
      :c => ["hours", 'issue.status'],
      :sort => 'issue.status'
    }
    assert_response :success

    # Make sure that values are properly sorted
    values = css_select("td.issue-status").map(&:text).reject(&:blank?)
    assert_equal IssueStatus.where(:id => [1, 5, 3]).sorted.pluck(:name), values
  end

  def test_index_with_issue_tracker_filter
    Issue.where(:tracker_id => 2).update_all(:tracker_id => 1)
    issue = Issue.generate!(:project_id => 1, :tracker_id => 2)
    entry = TimeEntry.generate!(:issue => issue, :hours => 4.5)

    get :index, :params => {
      :f => ['issue.tracker_id'],
      :op => {'issue.tracker_id' => '='},
      :v => {'issue.tracker_id' => ['2']}
    }
    assert_response :success
    assert_equal [entry].map(&:id).map(&:to_s), css_select('input[name="ids[]"]').map {|e| e.attr('value')}
  end

  def test_index_with_issue_tracker_column
    issue = Issue.generate!(:project_id => 1, :tracker_id => 2)
    entry = TimeEntry.generate!(:issue => issue)

    get :index, :params => {
      :c => %w(project spent_on issue comments hours issue.tracker)
    }
    assert_response :success
    assert_select 'td.issue-tracker', :text => issue.tracker.name
  end

  def test_index_with_issue_tracker_sort
    TimeEntry.delete_all
    TimeEntry.generate!(:issue => Issue.generate!(:tracker_id => 1))
    TimeEntry.generate!(:issue => Issue.generate!(:tracker_id => 3))
    TimeEntry.generate!(:issue => Issue.generate!(:tracker_id => 2))
    TimeEntry.generate!(:project_id => 1)

    get :index, :params => {
      :c => ["hours", 'issue.tracker'],
      :sort => 'issue.tracker'
    }
    assert_response :success

    # Make sure that values are properly sorted
    values = css_select("td.issue-tracker").map(&:text).reject(&:blank?)
    assert_equal Tracker.where(:id => [1, 2, 3]).sorted.pluck(:name), values
  end

  def test_index_with_issue_category_filter
    get :index, :params => {
      :project_id => 'ecookbook',
      :f => ['issue.category_id'],
      :op => {'issue.category_id' => '='},
      :v => {'issue.category_id' => ['1']}
    }
    assert_response :success
    assert_equal ['1', '2'], css_select('input[name="ids[]"]').map {|e| e.attr('value')}
  end

  def test_index_with_issue_category_column
    get :index, :params => {
      :project_id => 'ecookbook',
      :c => %w(project spent_on issue comments hours issue.category)
    }

    assert_response :success
    assert_select 'td.issue-category', :text => 'Printing'
  end

  def test_index_with_issue_fixed_version_column
    issue = Issue.find(1)
    issue.fixed_version = Version.find(3)
    issue.save!

    get :index, :params => {
      :project_id => 'ecookbook',
      :c => %w(project spent_on issue comments hours issue.fixed_version)
    }

    assert_response :success
    assert_select 'td.issue-fixed_version', :text => '2.0'
  end

  def test_index_with_author_filter
    get :index, :params => {
      :project_id => 'ecookbook',
      :f => ['author_id'],
      :op => {'author_id' => '='},
      :v => {'author_id' => ['2']}
    }
    assert_response :success
    assert_equal ['1'], css_select('input[name="ids[]"]').map {|e| e.attr('value')}
  end

  def test_index_with_author_column
    get :index, :params => {
      :project_id => 'ecookbook',
      :c => %w(project spent_on issue comments hours author)
    }

    assert_response :success
    assert_select 'td.author', :text => 'Redmine Admin'
  end

  def test_index_with_issue_category_sort
    issue = Issue.find(3)
    issue.category_id = 2
    issue.save!

    get :index, :params => {
      :c => ["hours", 'issue.category'],
      :sort => 'issue.category'
    }
    assert_response :success

    # Make sure that values are properly sorted
    values = css_select("td.issue-category").map(&:text).reject(&:blank?)
    assert_equal ['Printing', 'Printing', 'Recipes'], values
  end

  def test_index_with_issue_fixed_version_sort
    issue = Issue.find(1)
    issue.fixed_version = Version.find(3)
    issue.save!

    TimeEntry.generate!(:issue => Issue.find(12))

    get :index, :params => {
      :project_id => 'ecookbook',
      :c => ["hours", 'issue.fixed_version'],
      :sort => 'issue.fixed_version'
    }

    assert_response :success
    # Make sure that values are properly sorted
    values = css_select("td.issue-fixed_version").map(&:text).reject(&:blank?)
    assert_equal ['1.0', '2.0', '2.0'], values
  end

  def test_index_with_filter_on_issue_custom_field
    issue = Issue.generate!(:project_id => 1, :tracker_id => 1, :custom_field_values => {2 => 'filter_on_issue_custom_field'})
    entry = TimeEntry.generate!(:issue => issue, :hours => 2.5)

    get :index, :params => {
      :f => ['issue.cf_2'],
      :op => {'issue.cf_2' => '='},
      :v => {'issue.cf_2' => ['filter_on_issue_custom_field']}
    }
    assert_response :success
    assert_equal [entry].map(&:id).map(&:to_s), css_select('input[name="ids[]"]').map {|e| e.attr('value')}
  end

  def test_index_with_issue_custom_field_column
    issue = Issue.generate!(:project_id => 1, :tracker_id => 1, :custom_field_values => {2 => 'filter_on_issue_custom_field'})
    entry = TimeEntry.generate!(:issue => issue, :hours => 2.5)

    get :index, :params => {
      :c => %w(project spent_on issue comments hours issue.cf_2)
    }
    assert_response :success
    assert_select 'td.issue_cf_2', :text => 'filter_on_issue_custom_field'
  end

  def test_index_with_time_entry_custom_field_column
    field = TimeEntryCustomField.generate!(:field_format => 'string')
    entry = TimeEntry.generate!(:hours => 2.5, :custom_field_values => {field.id => 'CF Value'})
    field_name = "cf_#{field.id}"

    get :index, :params => {
      :c => ["hours", field_name]
    }
    assert_response :success
    assert_select "td.#{field_name}", :text => 'CF Value'
  end

  def test_index_with_time_entry_custom_field_sorting
    field = TimeEntryCustomField.generate!(:field_format => 'string', :name => 'String Field')
    TimeEntry.generate!(:hours => 2.5, :custom_field_values => {field.id => 'CF Value 1'})
    TimeEntry.generate!(:hours => 2.5, :custom_field_values => {field.id => 'CF Value 3'})
    TimeEntry.generate!(:hours => 2.5, :custom_field_values => {field.id => 'CF Value 2'})
    field_name = "cf_#{field.id}"

    get :index, :params => {
      :c => ["hours", field_name],
      :sort => field_name
    }
    assert_response :success
    assert_select "th.cf_#{field.id} a.sort", :text => 'String Field'

    # Make sure that values are properly sorted
    values = css_select("td.#{field_name}").map(&:text).reject(&:blank?)
    assert_equal values.sort, values
    assert_equal 3, values.size
  end

  def test_index_with_invalid_date_filter_should_not_validate
    @request.session[:user_id] = 2

    get :index, :params => {:set_filter => '1', :f => ['spent_on'], :op => {'spent_on' => '='}, :v => {'spent_on' => ['2016-09-010']}}
    assert_select_error 'Date is invalid'
    assert_select 'table.time-entries', 0
  end

  def test_index_with_query
    query = TimeEntryQuery.new(:project_id => 1, :name => 'Time Entry Query', :visibility => 2)
    query.save!
    @request.session[:user_id] = 2

    get :index, :params => {:project_id => 'ecookbook', :query_id => query.id}
    assert_response :success
    assert_select 'h2', :text => query.name
    assert_select '#sidebar a.selected', :text => query.name
  end

  def test_index_atom_feed
    get :index, :params => {:project_id => 1, :format => 'atom'}
    assert_response :success
    assert_equal 'application/atom+xml', @response.content_type
    assert_select 'entry > title', :text => /7\.65 hours/
  end

  def test_index_at_project_level_should_include_csv_export_dialog
    get :index, :params => {
      :project_id => 'ecookbook',
      :f => ['spent_on'],
      :op => {'spent_on' => '>='},
      :v => {'spent_on' => ['2007-04-01']},
      :c => ['spent_on', 'user']
    }
    assert_response :success

    assert_select '#csv-export-options' do
      assert_select 'form[action=?][method=get]', '/projects/ecookbook/time_entries.csv' do
        # filter
        assert_select 'input[name=?][value=?]', 'f[]', 'spent_on'
        assert_select 'input[name=?][value=?]', 'op[spent_on]', '>='
        assert_select 'input[name=?][value=?]', 'v[spent_on][]', '2007-04-01'
        # columns
        assert_select 'input[name=?][type=hidden][value=?]', 'c[]', 'spent_on'
        assert_select 'input[name=?][type=hidden][value=?]', 'c[]', 'user'
        assert_select 'input[name=?][type=hidden]', 'c[]', 2
        assert_select 'input[name=?][value=?]', 'c[]', 'all_inline'
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

  def test_index_csv_all_projects
    with_settings :date_format => '%m/%d/%Y' do
      get :index, :params => {:format => 'csv'}
      assert_response :success
      assert_equal 'text/csv', response.media_type
    end
  end

  def test_index_csv
    with_settings :date_format => '%m/%d/%Y' do
      get :index, :params => {:project_id => 1, :format => 'csv'}
      assert_response :success
      assert_equal 'text/csv', response.media_type
    end
  end

  def test_index_csv_should_fill_issue_column_with_tracker_id_and_subject
    issue = Issue.find(1)
    entry = TimeEntry.generate!(:issue => issue, :comments => "Issue column content test")

    get :index, :params => {:format => 'csv'}
    line = response.body.split("\n").detect {|l| l.include?(entry.comments)}
    assert_not_nil line
    assert_include "#{issue.tracker} #1: #{issue.subject}", line
  end

  def test_index_csv_should_fill_issue_column_with_issue_id_if_issue_that_is_not_visible
    @request.session[:user_id] = 3
    issue = Issue.generate!(:author_id => 1, :is_private => true)
    entry = TimeEntry.generate!(:issue => issue, :comments => "Issue column content test")

    get :index, :params => {:format => 'csv'}
    assert_not issue.visible?
    line = response.body.split("\n").detect {|l| l.include?(entry.comments)}
    assert_not_nil line
    assert_not_include "#{issue.tracker} ##{issue.id}: #{issue.subject}", line
    assert_include "##{issue.id}", line
  end

  def test_index_grouped_by_created_on
    skip unless TimeEntryQuery.new.groupable_columns.detect {|c| c.name == :created_on}

    get :index, :params => {
        :set_filter => 1,
        :group_by => 'created_on'
      }
    assert_response :success

    assert_select 'tr.group span.name', :text => '03/23/2007' do
      assert_select '+ span.count', :text => '2'
    end
  end

  def test_index_with_inline_issue_long_text_custom_field_column
    field = IssueCustomField.create!(:name => 'Long text', :field_format => 'text', :full_width_layout => '1',
      :tracker_ids => [1], :is_for_all => true)
    issue = Issue.find(1)
    issue.custom_field_values = {field.id => 'This is a long text'}
    issue.save!

    get :index, :params => {
        :set_filter => 1,
        :c => ['subject', 'description', "issue.cf_#{field.id}"]
      }
    assert_response :success
    assert_select "td.issue_cf_#{field.id}", :text => 'This is a long text'
  end
end
