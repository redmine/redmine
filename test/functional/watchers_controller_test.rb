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

class WatchersControllerTest < ActionController::TestCase
  fixtures :projects, :users, :roles, :members, :member_roles, :enabled_modules,
           :issues, :trackers, :projects_trackers, :issue_statuses, :enumerations, :watchers

  def setup
    User.current = nil
  end

  def test_watch_a_single_object
    @request.session[:user_id] = 3
    assert_difference('Watcher.count') do
      xhr :post, :watch, :object_type => 'issue', :object_id => '1'
      assert_response :success
      assert_include '$(".issue-1-watcher")', response.body
    end
    assert Issue.find(1).watched_by?(User.find(3))
  end

  def test_watch_a_collection_with_a_single_object
    @request.session[:user_id] = 3
    assert_difference('Watcher.count') do
      xhr :post, :watch, :object_type => 'issue', :object_id => ['1']
      assert_response :success
      assert_include '$(".issue-1-watcher")', response.body
    end
    assert Issue.find(1).watched_by?(User.find(3))
  end

  def test_watch_a_collection_with_multiple_objects
    @request.session[:user_id] = 3
    assert_difference('Watcher.count', 2) do
      xhr :post, :watch, :object_type => 'issue', :object_id => ['1', '3']
      assert_response :success
      assert_include '$(".issue-bulk-watcher")', response.body
    end
    assert Issue.find(1).watched_by?(User.find(3))
    assert Issue.find(3).watched_by?(User.find(3))
  end

  def test_watch_should_be_denied_without_permission
    Role.find(2).remove_permission! :view_issues
    @request.session[:user_id] = 3
    assert_no_difference('Watcher.count') do
      xhr :post, :watch, :object_type => 'issue', :object_id => '1'
      assert_response 403
    end
  end

  def test_watch_invalid_class_should_respond_with_404
    @request.session[:user_id] = 3
    assert_no_difference('Watcher.count') do
      xhr :post, :watch, :object_type => 'foo', :object_id => '1'
      assert_response 404
    end
  end

  def test_watch_invalid_object_should_respond_with_404
    @request.session[:user_id] = 3
    assert_no_difference('Watcher.count') do
      xhr :post, :watch, :object_type => 'issue', :object_id => '999'
      assert_response 404
    end
  end

  def test_unwatch
    @request.session[:user_id] = 3
    assert_difference('Watcher.count', -1) do
      xhr :delete, :unwatch, :object_type => 'issue', :object_id => '2'
      assert_response :success
      assert_include '$(".issue-2-watcher")', response.body
    end
    assert !Issue.find(1).watched_by?(User.find(3))
  end

  def test_unwatch_a_collection_with_multiple_objects
    @request.session[:user_id] = 3
    Watcher.create!(:user_id => 3, :watchable => Issue.find(1))
    Watcher.create!(:user_id => 3, :watchable => Issue.find(3))

    assert_difference('Watcher.count', -2) do
      xhr :delete, :unwatch, :object_type => 'issue', :object_id => ['1', '3']
      assert_response :success
      assert_include '$(".issue-bulk-watcher")', response.body
    end
    assert !Issue.find(1).watched_by?(User.find(3))
    assert !Issue.find(3).watched_by?(User.find(3))
  end

  def test_new
    @request.session[:user_id] = 2
    xhr :get, :new, :object_type => 'issue', :object_id => '2'
    assert_response :success
    assert_match /ajax-modal/, response.body
  end

  def test_new_for_new_record_with_project_id
    @request.session[:user_id] = 2
    xhr :get, :new, :project_id => 1
    assert_response :success
    assert_equal Project.find(1), assigns(:project)
    assert_match /ajax-modal/, response.body
  end

  def test_new_for_new_record_with_project_identifier
    @request.session[:user_id] = 2
    xhr :get, :new, :project_id => 'ecookbook'
    assert_response :success
    assert_equal Project.find(1), assigns(:project)
    assert_match /ajax-modal/, response.body
  end

  def test_create
    @request.session[:user_id] = 2
    assert_difference('Watcher.count') do
      xhr :post, :create, :object_type => 'issue', :object_id => '2', :watcher => {:user_id => '4'}
      assert_response :success
      assert_match /watchers/, response.body
      assert_match /ajax-modal/, response.body
    end
    assert Issue.find(2).watched_by?(User.find(4))
  end

  def test_create_multiple
    @request.session[:user_id] = 2
    assert_difference('Watcher.count', 2) do
      xhr :post, :create, :object_type => 'issue', :object_id => '2', :watcher => {:user_ids => ['4', '7']}
      assert_response :success
      assert_match /watchers/, response.body
      assert_match /ajax-modal/, response.body
    end
    assert Issue.find(2).watched_by?(User.find(4))
    assert Issue.find(2).watched_by?(User.find(7))
  end

  def test_autocomplete_on_watchable_creation
    @request.session[:user_id] = 2
    xhr :get, :autocomplete_for_user, :q => 'mi', :project_id => 'ecookbook'
    assert_response :success
    assert_select 'input', :count => 4
    assert_select 'input[name=?][value=1]', 'watcher[user_ids][]'
    assert_select 'input[name=?][value=2]', 'watcher[user_ids][]'
    assert_select 'input[name=?][value=8]', 'watcher[user_ids][]'
    assert_select 'input[name=?][value=9]', 'watcher[user_ids][]'
  end

  def test_autocomplete_on_watchable_update
    @request.session[:user_id] = 2
    xhr :get, :autocomplete_for_user, :q => 'mi', :object_id => '2' , :object_type => 'issue', :project_id => 'ecookbook'
    assert_response :success
    assert_select 'input', :count => 3
    assert_select 'input[name=?][value=2]', 'watcher[user_ids][]'
    assert_select 'input[name=?][value=8]', 'watcher[user_ids][]'
    assert_select 'input[name=?][value=9]', 'watcher[user_ids][]'

  end

  def test_append
    @request.session[:user_id] = 2
    assert_no_difference 'Watcher.count' do
      xhr :post, :append, :watcher => {:user_ids => ['4', '7']}, :project_id => 'ecookbook'
      assert_response :success
      assert_include 'watchers_inputs', response.body
      assert_include 'issue[watcher_user_ids][]', response.body
    end
  end

  def test_remove_watcher
    @request.session[:user_id] = 2
    assert_difference('Watcher.count', -1) do
      xhr :delete, :destroy, :object_type => 'issue', :object_id => '2', :user_id => '3'
      assert_response :success
      assert_match /watchers/, response.body
    end
    assert !Issue.find(2).watched_by?(User.find(3))
  end
end
