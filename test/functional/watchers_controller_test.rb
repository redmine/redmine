# Redmine - project management software
# Copyright (C) 2006-2017  Jean-Philippe Lang
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

class WatchersControllerTest < Redmine::ControllerTest
  fixtures :projects, :users, :roles, :members, :member_roles, :enabled_modules,
           :issues, :trackers, :projects_trackers, :issue_statuses, :enumerations, :watchers

  def setup
    User.current = nil
  end

  def test_watch_a_single_object_as_html
    @request.session[:user_id] = 3
    assert_difference('Watcher.count') do
      post :watch, :params => {:object_type => 'issue', :object_id => '1'}
      assert_response :success
      assert_include 'Watcher added', response.body
    end
    assert Issue.find(1).watched_by?(User.find(3))
  end

  def test_watch_a_single_object
    @request.session[:user_id] = 3
    assert_difference('Watcher.count') do
      post :watch, :params => {:object_type => 'issue', :object_id => '1'}, :xhr => true
      assert_response :success
      assert_include '$(".issue-1-watcher")', response.body
    end
    assert Issue.find(1).watched_by?(User.find(3))
  end

  def test_watch_a_collection_with_a_single_object
    @request.session[:user_id] = 3
    assert_difference('Watcher.count') do
      post :watch, :params => {:object_type => 'issue', :object_id => ['1']}, :xhr => true
      assert_response :success
      assert_include '$(".issue-1-watcher")', response.body
    end
    assert Issue.find(1).watched_by?(User.find(3))
  end

  def test_watch_a_collection_with_multiple_objects
    @request.session[:user_id] = 3
    assert_difference('Watcher.count', 2) do
      post :watch, :params => {:object_type => 'issue', :object_id => ['1', '3']}, :xhr => true
      assert_response :success
      assert_include '$(".issue-bulk-watcher")', response.body
    end
    assert Issue.find(1).watched_by?(User.find(3))
    assert Issue.find(3).watched_by?(User.find(3))
  end

  def test_watch_a_news_module_should_add_watcher
    @request.session[:user_id] = 7
    assert_not_nil m = Project.find(1).enabled_module('news')

    assert_difference 'Watcher.count' do
      post :watch, :params => {:object_type => 'enabled_module', :object_id => m.id.to_s}, :xhr => true
      assert_response :success
    end
    assert m.reload.watched_by?(User.find(7))
  end

  def test_watch_a_private_news_module_without_permission_should_fail
    @request.session[:user_id] = 7
    assert_not_nil m = Project.find(2).enabled_module('news')

    assert_no_difference 'Watcher.count' do
      post :watch, :params => {:object_type => 'enabled_module', :object_id => m.id.to_s}, :xhr => true
      assert_response 403
    end
  end

  def test_watch_should_be_denied_without_permission
    Role.find(2).remove_permission! :view_issues
    @request.session[:user_id] = 3
    assert_no_difference('Watcher.count') do
      post :watch, :params => {:object_type => 'issue', :object_id => '1'}, :xhr => true
      assert_response 403
    end
  end

  def test_watch_invalid_class_should_respond_with_404
    @request.session[:user_id] = 3
    assert_no_difference('Watcher.count') do
      post :watch, :params => {:object_type => 'foo', :object_id => '1'}, :xhr => true
      assert_response 404
    end
  end

  def test_watch_invalid_object_should_respond_with_404
    @request.session[:user_id] = 3
    assert_no_difference('Watcher.count') do
      post :watch, :params => {:object_type => 'issue', :object_id => '999'}, :xhr => true
      assert_response 404
    end
  end

  def test_unwatch_as_html
    @request.session[:user_id] = 3
    assert_difference('Watcher.count', -1) do
      delete :unwatch, :params => {:object_type => 'issue', :object_id => '2'}
      assert_response :success
      assert_include 'Watcher removed', response.body
    end
    assert !Issue.find(1).watched_by?(User.find(3))
  end

  def test_unwatch
    @request.session[:user_id] = 3
    assert_difference('Watcher.count', -1) do
      delete :unwatch, :params => {:object_type => 'issue', :object_id => '2'}, :xhr => true
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
      delete :unwatch, :params => {:object_type => 'issue', :object_id => ['1', '3']}, :xhr => true
      assert_response :success
      assert_include '$(".issue-bulk-watcher")', response.body
    end
    assert !Issue.find(1).watched_by?(User.find(3))
    assert !Issue.find(3).watched_by?(User.find(3))
  end

  def test_new
    @request.session[:user_id] = 2
    get :new, :params => {:object_type => 'issue', :object_id => '2'}, :xhr => true
    assert_response :success
    assert_match /ajax-modal/, response.body
  end

  def test_new_with_multiple_objects
    @request.session[:user_id] = 2
    get :new, :params => {:object_type => 'issue', :object_id => ['1', '2']}, :xhr => true
    assert_response :success
    assert_match /ajax-modal/, response.body
  end

  def test_new_for_new_record_with_project_id
    @request.session[:user_id] = 2
    get :new, :params => {:project_id => 1}, :xhr => true
    assert_response :success
    assert_match /ajax-modal/, response.body
  end

  def test_new_for_new_record_with_project_identifier
    @request.session[:user_id] = 2
    get :new, :params => {:project_id => 'ecookbook'}, :xhr => true
    assert_response :success
    assert_match /ajax-modal/, response.body
  end

  def test_create_as_html
    @request.session[:user_id] = 2
    assert_difference('Watcher.count') do
      post :create, :params => {
        :object_type => 'issue', :object_id => '2',
        :watcher => {:user_id => '4'}
      }
      assert_response :success
      assert_include 'Watcher added', response.body
    end
    assert Issue.find(2).watched_by?(User.find(4))
  end

  def test_create
    @request.session[:user_id] = 2
    assert_difference('Watcher.count') do
      post :create, :params => {
        :object_type => 'issue', :object_id => '2',
        :watcher => {:user_id => '4'}
      }, :xhr => true
      assert_response :success
      assert_match /watchers/, response.body
      assert_match /ajax-modal/, response.body
    end
    assert Issue.find(2).watched_by?(User.find(4))
  end

  def test_create_with_mutiple_users
    @request.session[:user_id] = 2
    assert_difference('Watcher.count', 2) do
      post :create, :params => {
        :object_type => 'issue', :object_id => '2',
        :watcher => {:user_ids => ['4', '7']}
      }, :xhr => true
      assert_response :success
      assert_match /watchers/, response.body
      assert_match /ajax-modal/, response.body
    end
    assert Issue.find(2).watched_by?(User.find(4))
    assert Issue.find(2).watched_by?(User.find(7))
  end

  def test_create_with_mutiple_objects
    @request.session[:user_id] = 2
    assert_difference('Watcher.count', 4) do
      post :create, :params => {
        :object_type => 'issue', :object_id => ['1', '2'],
        :watcher => {:user_ids => ['4', '7']}
      }, :xhr => true
      assert_response :success
      assert_match /watchers/, response.body
      assert_match /ajax-modal/, response.body
    end
    assert Issue.find(1).watched_by?(User.find(4))
    assert Issue.find(2).watched_by?(User.find(4))
    assert Issue.find(1).watched_by?(User.find(7))
    assert Issue.find(2).watched_by?(User.find(7))
  end

  def test_autocomplete_on_watchable_creation
    @request.session[:user_id] = 2
    get :autocomplete_for_user, :params => {:q => 'mi', :project_id => 'ecookbook'}, :xhr => true
    assert_response :success
    assert_select 'input', :count => 4
    assert_select 'input[name=?][value="1"]', 'watcher[user_ids][]'
    assert_select 'input[name=?][value="2"]', 'watcher[user_ids][]'
    assert_select 'input[name=?][value="8"]', 'watcher[user_ids][]'
    assert_select 'input[name=?][value="9"]', 'watcher[user_ids][]'
  end

  def test_search_non_member_on_create
    @request.session[:user_id] = 2
    project = Project.find_by_name("ecookbook")
    user = User.generate!(:firstname => 'issue15622')
    membership = user.membership(project)
    assert_nil membership
    get :autocomplete_for_user, :params => {:q => 'issue15622', :project_id => 'ecookbook'}, :xhr => true
    assert_response :success
    assert_select 'input', :count => 1
  end

  def test_autocomplete_on_watchable_update
    @request.session[:user_id] = 2
    get :autocomplete_for_user, :params => {
      :object_type => 'issue', :object_id => '2',
      :project_id => 'ecookbook', :q => 'mi'
    }, :xhr => true
    assert_response :success
    assert_select 'input', :count => 3
    assert_select 'input[name=?][value="2"]', 'watcher[user_ids][]'
    assert_select 'input[name=?][value="8"]', 'watcher[user_ids][]'
    assert_select 'input[name=?][value="9"]', 'watcher[user_ids][]'
  end

  def test_search_and_add_non_member_on_update
    @request.session[:user_id] = 2
    project = Project.find_by_name("ecookbook")
    user = User.generate!(:firstname => 'issue15622')
    membership = user.membership(project)
    assert_nil membership

    get :autocomplete_for_user, :params => {
      :object_type => 'issue', :object_id => '2',
      :project_id => 'ecookbook', :q => 'issue15622'
    }, :xhr => true
    assert_response :success
    assert_select 'input', :count => 1

    assert_difference('Watcher.count', 1) do
      post :create, :params => {
        :object_type => 'issue', :object_id => '2',
        :watcher => {:user_ids => ["#{user.id}"]}
      }, :xhr => true
      assert_response :success
      assert_match /watchers/, response.body
      assert_match /ajax-modal/, response.body
    end
    assert Issue.find(2).watched_by?(user)
  end

  def test_autocomplete_for_user_should_return_visible_users
    Role.update_all :users_visibility => 'members_of_visible_projects'

    hidden = User.generate!(:lastname => 'autocomplete_hidden')
    visible = User.generate!(:lastname => 'autocomplete_visible')
    User.add_to_project(visible, Project.find(1))

    @request.session[:user_id] = 2
    get :autocomplete_for_user, :params => {:q => 'autocomp', :project_id => 'ecookbook'}, :xhr => true
    assert_response :success

    assert_include visible.name, response.body
    assert_not_include hidden.name, response.body
  end

  def test_append
    @request.session[:user_id] = 2
    assert_no_difference 'Watcher.count' do
      post :append, :params => {
        :watcher => {:user_ids => ['4', '7']}, :project_id => 'ecookbook'
      }, :xhr => true
      assert_response :success
      assert_include 'watchers_inputs', response.body
      assert_include 'issue[watcher_user_ids][]', response.body
    end
  end

  def test_append_without_user_should_render_nothing
    @request.session[:user_id] = 2
    post :append, :params => {:project_id => 'ecookbook'}, :xhr => true
    assert_response :success
    assert response.body.blank?
  end

  def test_destroy_as_html
    @request.session[:user_id] = 2
    assert_difference('Watcher.count', -1) do
      delete :destroy, :params => {
        :object_type => 'issue', :object_id => '2', :user_id => '3'
      }
      assert_response :success
      assert_include 'Watcher removed', response.body
    end
    assert !Issue.find(2).watched_by?(User.find(3))
  end

  def test_destroy
    @request.session[:user_id] = 2
    assert_difference('Watcher.count', -1) do
      delete :destroy, :params => {
        :object_type => 'issue', :object_id => '2', :user_id => '3'
      }, :xhr => true
      assert_response :success
      assert_match /watchers/, response.body
    end
    assert !Issue.find(2).watched_by?(User.find(3))
  end

  def test_destroy_locked_user
    user = User.find(3)
    user.lock!
    assert user.reload.locked?

    @request.session[:user_id] = 2
    assert_difference('Watcher.count', -1) do
      delete :destroy, :params => {
        :object_type => 'issue', :object_id => '2', :user_id => '3'
      }, :xhr => true
      assert_response :success
      assert_match /watchers/, response.body
    end
    assert !Issue.find(2).watched_by?(User.find(3))
  end

  def test_destroy_invalid_user_should_respond_with_404
    @request.session[:user_id] = 2
    assert_no_difference('Watcher.count') do
      delete :destroy, :params => {
        :object_type => 'issue', :object_id => '2', :user_id => '999'
      }
      assert_response 404
    end
  end
end
