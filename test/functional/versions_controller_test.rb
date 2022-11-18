# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2022  Jean-Philippe Lang
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

class VersionsControllerTest < Redmine::ControllerTest
  fixtures :projects, :enabled_modules,
           :trackers, :projects_trackers,
           :versions, :issue_statuses, :issue_categories, :enumerations,
           :issues,
           :users, :email_addresses,
           :roles, :members, :member_roles

  def setup
    User.current = nil
  end

  def test_index
    get :index, :params => {:project_id => 1}
    assert_response :success

    # Version with no date set appears
    assert_select 'h3', :text => "#{Version.find(3).name}"
    assert_select 'span[class=?]', 'badge badge-status-open', :text => 'open'

    # Completed version doesn't appear
    assert_select 'h3', :text => Version.find(1).name, :count => 0

    # Context menu on issues
    assert_select "form[data-cm-url=?]", '/issues/context_menu'
    assert_select "div#sidebar" do
      # Tracker checkboxes
      assert_select 'input[type=hidden][name=?]', 'tracker_ids[]'
      assert_select 'input[type=checkbox][name=?]', 'tracker_ids[]', 3
      # Links to versions anchors
      assert_select 'a[href=?]', '#2.0'
      # Links to completed versions in the sidebar
      assert_select 'a[href=?]', '/versions/1'
    end
  end

  def test_index_with_completed_versions
    get :index, :params => {:project_id => 1, :completed => 1}
    assert_response :success

    # Version with no date set appears
    assert_select 'h3', :text => Version.find(3).name
    # Completed version appears
    assert_select 'h3', :text => Version.find(1).name
  end

  def test_index_with_tracker_ids
    (1..3).each do |tracker_id|
      Issue.generate! :project_id => 1, :fixed_version_id => 3, :tracker_id => tracker_id
    end
    get :index, :params => {:project_id => 1, :tracker_ids => [1, 3]}
    assert_response :success
    assert_select 'a.issue.tracker-1'
    assert_select 'a.issue.tracker-2', 0
    assert_select 'a.issue.tracker-3'
  end

  def test_index_showing_subprojects_versions
    version_name = "Subproject version"
    Version.create!(:project => Project.find(3), :name => version_name)
    get :index, :params => {:project_id => 1, :with_subprojects => 1}
    assert_response :success

    # Shared version
    assert_select 'h3', :text => Version.find(4).name
    # Subproject version
    assert_select 'h3', :text => /#{version_name}/
  end

  def test_index_should_prepend_shared_versions
    get :index, :params => {:project_id => 1}
    assert_response :success

    assert_select '#sidebar' do
      assert_select 'a[href=?]', '#2.0', :text => '2.0'
      assert_select 'a[href=?]', '#subproject1-2.0', :text => 'eCookbook Subproject 1 - 2.0'
    end
    assert_select '#content' do
      assert_select 'a[name=?]', '2.0', :text => '2.0'
      assert_select 'a[name=?]', 'subproject1-2.0', :text => 'eCookbook Subproject 1 - 2.0'
    end
  end

  def test_index_should_show_issue_assignee
    with_settings :gravatar_enabled => '1' do
      Issue.generate!(:project_id => 3, :fixed_version_id => 4, :assigned_to => User.find_by_login('jsmith'))
      Issue.generate!(:project_id => 3, :fixed_version_id => 4)

      get :index, :params => {:project_id => 3}
      assert_response :success

      assert_select 'table.related-issues' do
        assert_select 'tr.issue', :count => 2 do
          assert_select 'img.gravatar[title=?]', 'Assignee: John Smith', :count => 1
        end
      end
    end
  end

  def test_show
    with_settings :gravatar_enabled => '0' do
      get :show, :params => {:id => 2}
      assert_response :success

      assert_select 'h2', :text => /1.0/
      assert_select 'span[class=?]', 'badge badge-status-locked', :text => 'locked'

      # no issue avatar when gravatar is disabled
      assert_select 'img.gravatar', :count => 0
    end
  end

  def test_show_should_show_issue_assignee
    with_settings :gravatar_enabled => '1' do
      get :show, :params => {:id => 2}
      assert_response :success

      assert_select 'table.related-issues' do
        assert_select 'tr.issue td.assigned_to', :count => 2 do
          assert_select 'img.gravatar[title=?]', 'Assignee: Dave Lopper', :count => 1
        end
      end
    end
  end

  def test_show_issue_calculations_should_take_into_account_only_visible_issues
    issue_9 = Issue.find(9)
    issue_9.fixed_version_id = 4
    issue_9.estimated_hours = 3
    issue_9.save!

    issue_13 = Issue.find(13)
    issue_13.fixed_version_id = 4
    issue_13.estimated_hours = 2
    issue_13.save!

    @request.session[:user_id] = 7

    get :show, :params => {:id => 4}
    assert_response :success

    assert_select 'p.progress-info' do
      assert_select 'a', :text => '1 issue'
      assert_select 'a', :text => '1 open'
    end

    assert_select '.time-tracking td.total-hours a:first-child', :text => '2:00 hours'
  end

  def test_show_should_link_to_spent_time_on_version
    version = Version.generate!
    issue = Issue.generate(:fixed_version => version)
    TimeEntry.generate!(:issue => issue, :hours => 7.2)

    get :show, :params => {:id => version.id}
    assert_response :success

    assert_select '.total-hours', :text => '7:12 hours'
    assert_select '.total-hours a[href=?]', "/projects/ecookbook/time_entries?issue.fixed_version_id=#{version.id}&set_filter=1"
  end

  def test_show_should_display_nil_counts
    with_settings :default_language => 'en' do
      get :show, :params => {:id => 2, :status_by => 'category'}
      assert_response :success
      assert_select 'div#status_by' do
        assert_select 'select[name=status_by]' do
          assert_select 'option[value=category][selected=selected]'
        end
        assert_select 'a', :text => 'none'
      end
    end
  end

  def test_show_should_round_down_progress_percentages
    issue = Issue.find(12)
    issue.estimated_hours = 40
    issue.save!

    with_settings :default_language => 'en' do
      get :show, :params => {:id => 2}
      assert_response :success

      assert_select 'div.version-overview' do
        assert_select 'table.progress-98' do
          assert_select 'td[class=closed][title=?]', 'closed: 98%'
          assert_select 'td[class=done][title=?]', '% Done: 99%'
        end
        assert_select 'p[class=percent]', :text => '99%'
      end
    end
  end

  def test_show_should_display_link_to_new_issue
    @request.session[:user_id] = 1
    get :show, :params => {:id => 3}

    assert_response :success
    assert_select 'a.icon.icon-add', :text => 'New issue'
  end

  def test_new
    @request.session[:user_id] = 2
    get :new, :params => {:project_id => '1'}
    assert_response :success
    assert_select 'input[name=?]', 'version[name]'
    assert_select 'select[name=?]', 'version[status]', false
  end

  def test_new_from_issue_form
    @request.session[:user_id] = 2
    get :new, :params => {:project_id => '1'}, :xhr => true
    assert_response :success
    assert_equal 'text/javascript', response.media_type
  end

  def test_create
    @request.session[:user_id] = 2 # manager
    assert_difference 'Version.count' do
      post :create, :params => {:project_id => '1', :version => {:name => 'test_add_version'}}
    end
    assert_redirected_to '/projects/ecookbook/settings/versions'
    version = Version.find_by_name('test_add_version')
    assert_not_nil version
    assert_equal 1, version.project_id
  end

  def test_create_from_issue_form
    @request.session[:user_id] = 2
    assert_difference 'Version.count' do
      post :create, :params => {:project_id => '1', :version => {:name => 'test_add_version_from_issue_form'}}, :xhr => true
    end
    version = Version.find_by_name('test_add_version_from_issue_form')
    assert_not_nil version
    assert_equal 1, version.project_id

    assert_response :success
    assert_equal 'text/javascript', response.media_type
    assert_include 'test_add_version_from_issue_form', response.body
  end

  def test_create_from_issue_form_with_failure
    @request.session[:user_id] = 2
    assert_no_difference 'Version.count' do
      post :create, :params => {:project_id => '1', :version => {:name => ''}}, :xhr => true
    end
    assert_response :success
    assert_equal 'text/javascript', response.media_type
  end

  def test_get_edit
    @request.session[:user_id] = 2
    get :edit, :params => {:id => 2}
    assert_response :success
    version = Version.find(2)

    assert_select 'select[name=?]', 'version[status]' do
      assert_select 'option[value=?][selected="selected"]', version.status
    end
    assert_select 'input[name=?][value=?]', 'version[name]', version.name
  end

  def test_close_completed
    Version.update_all("status = 'open'")
    @request.session[:user_id] = 2
    put :close_completed, :params => {:project_id => 'ecookbook'}
    assert_redirected_to :controller => 'projects', :action => 'settings',
                         :tab => 'versions', :id => 'ecookbook'
    assert_not_nil Version.find_by_status('closed')
  end

  def test_post_update
    @request.session[:user_id] = 2
    put :update, :params => {
      :id => 2,
      :version => {
        :name => 'New version name',
        :effective_date => Date.today.strftime("%Y-%m-%d")
      }
    }
    assert_redirected_to :controller => 'projects', :action => 'settings',
                         :tab => 'versions', :id => 'ecookbook'
    version = Version.find(2)
    assert_equal 'New version name', version.name
    assert_equal Date.today, version.effective_date
  end

  def test_post_update_with_validation_failure
    @request.session[:user_id] = 2
    put :update, :params => {
      :id => 2,
      :version => {
        :name => '',
        :effective_date => Date.today.strftime("%Y-%m-%d")
      }
    }
    assert_response :success
    assert_select_error /Name cannot be blank/
  end

  def test_destroy
    @request.session[:user_id] = 2
    assert_difference 'Version.count', -1 do
      delete :destroy, :params => {:id => 3}
    end
    assert_redirected_to :controller => 'projects', :action => 'settings',
                         :tab => 'versions', :id => 'ecookbook'
    assert_nil Version.find_by_id(3)
  end

  def test_destroy_version_in_use_should_fail
    @request.session[:user_id] = 2
    assert_no_difference 'Version.count' do
      delete :destroy, :params => {:id => 2}
    end
    assert_redirected_to :controller => 'projects', :action => 'settings',
                         :tab => 'versions', :id => 'ecookbook'
    assert flash[:error].match(/Unable to delete version/)
    assert Version.find_by_id(2)
  end

  def test_issue_status_by
    get :status_by, :params => {:id => 2}, :xhr => true
    assert_response :success
  end

  def test_issue_status_by_status
    get :status_by, :params => {:id => 2, :status_by => 'status'}, :xhr => true
    assert_response :success
    assert_include 'Assigned', response.body
    assert_include 'Closed', response.body
  end
end
