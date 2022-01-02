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

class ActivitiesControllerTest < Redmine::ControllerTest
  fixtures :projects, :trackers, :issue_statuses, :issues,
           :enumerations, :users, :issue_categories,
           :projects_trackers,
           :roles,
           :member_roles,
           :members,
           :groups_users,
           :enabled_modules,
           :journals, :journal_details,
           :attachments, :changesets, :documents, :messages, :news, :time_entries, :wiki_content_versions

  def test_project_index
    get(
      :index,
      :params => {
        :id => 1,
        :with_subprojects => 0
      }
    )
    assert_response :success

    assert_select 'h3', :text => /#{2.days.ago.to_date.day}/
    assert_select 'dl dt.issue-edit a', :text => /(#{IssueStatus.find(2).name})/
  end

  def test_project_index_with_invalid_project_id_should_respond_404
    get(:index, :params => {:id => 299})
    assert_response 404
  end

  def test_previous_project_index
    @request.session[:user_id] = 1
    get(
      :index,
      :params => {
        :id => 1,
        :from => 2.days.ago.to_date
      }
    )
    assert_response :success

    assert_select 'h3', :text => /#{User.current.time_to_date(3.days.ago).day}/
    assert_select 'dl dt.issue a', :text => /Cannot print recipes/
  end

  def test_global_index
    @request.session[:user_id] = 1
    get :index
    assert_response :success

    i5 = Issue.find(5)
    d5 = User.find(1).time_to_date(i5.created_on)

    assert_select 'h3', :text => /#{d5.day}/
    assert_select 'dl dt.issue a', :text => /Subproject issue/
  end

  def test_user_index
    @request.session[:user_id] = 1
    get(
      :index,
      :params => {
        :user_id => 2
      }
    )
    assert_response :success

    assert_select 'h2 a[href="/users/2"]', :text => 'John Smith'
    assert_select '#sidebar select#user_id option[value="2"][selected=selected]'

    i1 = Issue.find(1)
    d1 = User.find(1).time_to_date(i1.created_on)

    assert_select 'h3', :text => /#{d1.day}/
    assert_select 'dl dt.issue a', :text => /Cannot print recipes/
  end

  def test_user_index_with_invalid_user_id_should_respond_404
    get(
      :index,
      :params => {
        :user_id => 299
      }
    )
    assert_response 404
  end

  def test_user_index_with_non_visible_user_id_should_respond_404
    Role.anonymous.update! :users_visibility => 'members_of_visible_projects'
    user = User.generate!

    @request.session[:user_id] = nil
    get :index, :params => {
      :user_id => user.id
    }

    assert_response 404
  end

  def test_index_atom_feed
    get(
      :index,
      :params => {
        :format => 'atom',
        :with_subprojects => 0
      }
    )
    assert_response :success

    assert_select 'feed' do
      assert_select 'link[rel=self][href=?]', 'http://test.host/activity.atom?with_subprojects=0'
      assert_select 'link[rel=alternate][href=?]', 'http://test.host/activity?with_subprojects=0'
      assert_select 'entry' do
        assert_select 'link[href=?]', 'http://test.host/issues/11'
      end
    end
  end

  def test_index_atom_feed_should_respect_feeds_limit_setting
    with_settings :feeds_limit => '20' do
      get(
        :index,
        :params => {
          :format => 'atom'
        }
      )
    end
    assert_response :success

    assert_select 'feed' do
      assert_select 'entry', :count => 20
    end
  end

  def test_index_atom_feed_with_explicit_selection
    get(
      :index,
      :params => {
        :format => 'atom',
        :with_subprojects => 0,
        :show_changesets => 1,
        :show_documents => 1,
        :show_files => 1,
        :show_issues => 1,
        :show_messages => 1,
        :show_news => 1,
        :show_time_entries => 1,
        :show_wiki_edits => 1
      }
    )
    assert_response :success

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
      get(
        :index,
        :params => {
          :format => 'atom',
          :show_issues => '1'
        }
      )
      assert_response :success
      assert_select 'title', :text => /Issues/
    end
  end

  def test_index_atom_feed_with_user
    get(
      :index,
      :params => {
        :user_id => 2,
        :format => 'atom'
      }
    )
    assert_response :success
    assert_select 'title', :text => "Redmine: #{User.find(2).name}"
  end

  def test_index_atom_feed_with_subprojects
    get(
      :index,
      :params => {
        :format => 'atom',
        :id => 'ecookbook',
        :with_subprojects => 1,
        :show_issues => 1
      }
    )
    assert_response :success

    assert_select 'feed' do
      # eCookbook
      assert_select 'title', text: 'Bug #1: Cannot print recipes'
      # eCookbook Subproject 1
      assert_select 'title', text: 'eCookbook Subproject 1 - Bug #5 (New): Subproject issue'
    end
  end

  def test_index_should_show_private_notes_with_permission_only
    journal = Journal.create!(:journalized => Issue.find(2), :notes => 'Private notes', :private_notes => true)
    @request.session[:user_id] = 2

    get :index
    assert_response :success
    assert_select 'dl', :text => /Private notes/

    Role.find(1).remove_permission! :view_private_notes
    get :index
    assert_response :success
    assert_select 'dl', :text => /Private notes/, :count => 0
  end

  def test_index_with_submitted_scope_should_save_as_preference
    @request.session[:user_id] = 2
    get(
      :index,
      :params => {
        :show_issues => '1',
        :show_messages => '1',
        :submit => 'Apply'
      }
    )
    assert_response :success
    assert_equal %w(issues messages), User.find(2).pref.activity_scope.sort
  end

  def test_index_scope_should_default_to_user_preference
    pref = User.find(2).pref
    pref.activity_scope = %w(issues news)
    pref.save!
    @request.session[:user_id] = 2

    get :index
    assert_response :success

    assert_select '#activity_scope_form' do
      assert_select 'input[checked=checked]', 2
      assert_select 'input[name=show_issues][checked=checked]'
      assert_select 'input[name=show_news][checked=checked]'
    end
  end

  def test_index_should_not_show_next_page_link
    @request.session[:user_id] = 2

    get :index
    assert_response :success
    assert_select '.pagination a', :text => /Previous/
    assert_select '.pagination a', :text => /Next/, :count => 0
  end

  def test_index_up_to_yesterday_should_show_next_page_link
    @request.session[:user_id] = 2
    get(
      :index,
      :params => {
        :from => (User.find(2).today - 1)
      }
    )
    assert_response :success
    assert_select '.pagination a', :text => /Previous/
    assert_select '.pagination a', :text => /Next/
  end
end
