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

class ActivitiesControllerTest < ActionController::TestCase
  fixtures :projects, :trackers, :issue_statuses, :issues,
           :enumerations, :users, :issue_categories,
           :projects_trackers,
           :roles,
           :member_roles,
           :members,
           :groups_users,
           :enabled_modules,
           :journals, :journal_details


  def test_project_index
    get :index, :id => 1, :with_subprojects => 0
    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:events_by_day)

    assert_select 'h3', :text => /#{2.days.ago.to_date.day}/
    assert_select 'dl dt.issue-edit a', :text => /(#{IssueStatus.find(2).name})/
  end

  def test_project_index_with_invalid_project_id_should_respond_404
    get :index, :id => 299
    assert_response 404
  end

  def test_previous_project_index
    get :index, :id => 1, :from => 2.days.ago.to_date
    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:events_by_day)

    assert_select 'h3', :text => /#{3.days.ago.to_date.day}/
    assert_select 'dl dt.issue a', :text => /Cannot print recipes/
  end

  def test_global_index
    @request.session[:user_id] = 1
    get :index
    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:events_by_day)

    i5 = Issue.find(5)
    d5 = User.find(1).time_to_date(i5.created_on)

    assert_select 'h3', :text => /#{d5.day}/
    assert_select 'dl dt.issue a', :text => /Subproject issue/
  end

  def test_user_index
    @request.session[:user_id] = 1
    get :index, :user_id => 2
    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:events_by_day)

    assert_select 'h2 a[href="/users/2"]', :text => 'John Smith'

    i1 = Issue.find(1)
    d1 = User.find(1).time_to_date(i1.created_on)

    assert_select 'h3', :text => /#{d1.day}/
    assert_select 'dl dt.issue a', :text => /Cannot print recipes/
  end

  def test_user_index_with_invalid_user_id_should_respond_404
    get :index, :user_id => 299
    assert_response 404
  end

  def test_index_atom_feed
    get :index, :format => 'atom', :with_subprojects => 0
    assert_response :success
    assert_template 'common/feed'

    assert_select 'feed' do
      assert_select 'link[rel=self][href=?]', 'http://test.host/activity.atom?with_subprojects=0'
      assert_select 'link[rel=alternate][href=?]', 'http://test.host/activity?with_subprojects=0'
      assert_select 'entry' do
        assert_select 'link[href=?]', 'http://test.host/issues/11'
      end
    end
  end

  def test_index_atom_feed_with_explicit_selection
    get :index, :format => 'atom', :with_subprojects => 0,
      :show_changesets => 1,
      :show_documents => 1,
      :show_files => 1,
      :show_issues => 1,
      :show_messages => 1,
      :show_news => 1,
      :show_time_entries => 1,
      :show_wiki_edits => 1

    assert_response :success
    assert_template 'common/feed'

    assert_select 'feed' do
      assert_select 'link[rel=self][href=?]', 'http://test.host/activity.atom?show_changesets=1&show_documents=1&show_files=1&show_issues=1&show_messages=1&show_news=1&show_time_entries=1&show_wiki_edits=1&with_subprojects=0'
      assert_select 'link[rel=alternate][href=?]', 'http://test.host/activity?show_changesets=1&show_documents=1&show_files=1&show_issues=1&show_messages=1&show_news=1&show_time_entries=1&show_wiki_edits=1&with_subprojects=0'
      assert_select 'entry' do
        assert_select 'link[href=?]', 'http://test.host/issues/11'
      end
    end
  end

  def test_index_atom_feed_with_one_item_type
    with_settings :default_language => 'en' do
      get :index, :format => 'atom', :show_issues => '1'
      assert_response :success
      assert_template 'common/feed'
  
      assert_select 'title', :text => /Issues/
    end
  end

  def test_index_atom_feed_with_user
    get :index, :user_id => 2, :format => 'atom'

    assert_response :success
    assert_template 'common/feed'
    assert_select 'title', :text => "Redmine: #{User.find(2).name}"
  end

  def test_index_should_show_private_notes_with_permission_only
    journal = Journal.create!(:journalized => Issue.find(2), :notes => 'Private notes with searchkeyword', :private_notes => true)
    @request.session[:user_id] = 2

    get :index
    assert_response :success
    assert_include journal, assigns(:events_by_day).values.flatten

    Role.find(1).remove_permission! :view_private_notes
    get :index
    assert_response :success
    assert_not_include journal, assigns(:events_by_day).values.flatten
  end
end
