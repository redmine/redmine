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

require File.expand_path('../../test_helper', __FILE__)

class IssueStatusesControllerTest < Redmine::ControllerTest
  fixtures :issue_statuses, :issues, :users, :trackers, :workflows

  def setup
    User.current = nil
    @request.session[:user_id] = 1 # admin
  end

  def test_index
    get :index
    assert_response :success
    assert_select 'table.issue_statuses'
  end

  def test_index_by_anonymous_should_redirect_to_login_form
    @request.session[:user_id] = nil
    get :index
    assert_redirected_to '/login?back_url=http%3A%2F%2Ftest.host%2Fissue_statuses'
  end

  def test_index_by_user_should_respond_with_406
    @request.session[:user_id] = 2
    get :index
    assert_response 406
  end

  def test_index_should_show_warning_when_no_workflow_is_defined
    status = IssueStatus.new :name => "No workflow"
    status.save!
    get :index
    assert_response :success
    assert_select 'table.issue_statuses tbody' do
      assert_select 'tr:not(:last-of-type) span.icon-warning', :count => 0
      assert_select 'tr:last-of-type' do
        assert_select 'td.name', :text => status.name
        assert_select 'td span.icon-warning',
                      :text => /#{I18n.t(:text_status_no_workflow)}/
      end
    end
  end

  def test_new
    get :new
    assert_response :success
    assert_select 'input[name=?]', 'issue_status[name]'
  end

  def test_create
    assert_difference 'IssueStatus.count' do
      post(
        :create,
        :params => {
          :issue_status => {
            :name => 'New status'
          }
        }
      )
    end
    assert_redirected_to :action => 'index'
    status = IssueStatus.order('id DESC').first
    assert_equal 'New status', status.name
  end

  def test_create_with_failure
    post(
      :create,
      :params => {
        :issue_status => {
          :name => ''
        }
      }
    )
    assert_response :success
    assert_select_error /name cannot be blank/i
  end

  def test_edit
    get(:edit, :params => {:id => '3'})
    assert_response :success
    assert_select 'input[name=?][value=?]', 'issue_status[name]', 'Resolved'
  end

  def test_update
    put(
      :update,
      :params => {
        :id => '3',
        :issue_status => {
          :name => 'Renamed status'
        }
      }
    )
    assert_redirected_to :action => 'index'
    status = IssueStatus.find(3)
    assert_equal 'Renamed status', status.name
  end

  def test_update_with_failure
    put(
      :update,
      :params => {
        :id => '3',
        :issue_status => {
          :name => ''
        }
      }
    )
    assert_response :success
    assert_select_error /name cannot be blank/i
  end

  def test_destroy
    Issue.where(:status_id => 1).delete_all
    Tracker.where(:default_status_id => 1).delete_all
    assert_difference 'IssueStatus.count', -1 do
      delete(:destroy, :params => {:id => '1'})
    end
    assert_redirected_to :action => 'index'
    assert_nil IssueStatus.find_by_id(1)
  end

  def test_destroy_should_block_if_status_is_used_by_issues
    assert Issue.where(:status_id => 1).any?
    Tracker.where(:default_status_id => 1).delete_all
    assert_no_difference 'IssueStatus.count' do
      delete(:destroy, :params => {:id => '1'})
    end
    assert_redirected_to :action => 'index'
    assert_not_nil IssueStatus.find_by_id(1)
  end

  def test_destroy_should_block_if_status_is_used_as_tracker_default_status
    Issue.where(:status_id => 1).delete_all
    assert Tracker.where(:default_status_id => 1).any?
    assert_no_difference 'IssueStatus.count' do
      delete(:destroy, :params => {:id => '1'})
    end
    assert_redirected_to :action => 'index'
    assert_not_nil IssueStatus.find_by_id(1)
  end

  def test_update_issue_done_ratio_with_issue_done_ratio_set_to_issue_field
    with_settings :issue_done_ratio => 'issue_field' do
      post :update_issue_done_ratio
      assert_match /not updated/, flash[:error].to_s
      assert_redirected_to '/issue_statuses'
    end
  end

  def test_update_issue_done_ratio_with_issue_done_ratio_set_to_issue_status
    with_settings :issue_done_ratio => 'issue_status' do
      post :update_issue_done_ratio
      assert_match /Issue done ratios updated/, flash[:notice].to_s
      assert_redirected_to '/issue_statuses'
    end
  end
end
