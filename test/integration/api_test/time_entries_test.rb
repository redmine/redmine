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

require File.expand_path('../../../test_helper', __FILE__)

class Redmine::ApiTest::TimeEntriesTest < Redmine::ApiTest::Base
  fixtures :projects, :trackers, :issue_statuses, :issues,
           :enumerations, :users, :issue_categories,
           :projects_trackers,
           :roles,
           :member_roles,
           :members,
           :enabled_modules,
           :time_entries

  def setup
    Setting.rest_api_enabled = '1'
  end

  test "GET /time_entries.xml should return time entries" do
    get '/time_entries.xml', {}, credentials('jsmith')
    assert_response :success
    assert_equal 'application/xml', @response.content_type
    assert_tag :tag => 'time_entries',
      :child => {:tag => 'time_entry', :child => {:tag => 'id', :content => '2'}}
  end

  test "GET /time_entries.xml with limit should return limited results" do
    get '/time_entries.xml?limit=2', {}, credentials('jsmith')
    assert_response :success
    assert_equal 'application/xml', @response.content_type
    assert_tag :tag => 'time_entries',
      :children => {:count => 2}
  end

  test "GET /time_entries/:id.xml should return the time entry" do
    get '/time_entries/2.xml', {}, credentials('jsmith')
    assert_response :success
    assert_equal 'application/xml', @response.content_type
    assert_tag :tag => 'time_entry',
      :child => {:tag => 'id', :content => '2'}
  end

  test "POST /time_entries.xml with issue_id should create time entry" do
    assert_difference 'TimeEntry.count' do
      post '/time_entries.xml', {:time_entry => {:issue_id => '1', :spent_on => '2010-12-02', :hours => '3.5', :activity_id => '11'}}, credentials('jsmith')
    end
    assert_response :created
    assert_equal 'application/xml', @response.content_type

    entry = TimeEntry.first(:order => 'id DESC')
    assert_equal 'jsmith', entry.user.login
    assert_equal Issue.find(1), entry.issue
    assert_equal Project.find(1), entry.project
    assert_equal Date.parse('2010-12-02'), entry.spent_on
    assert_equal 3.5, entry.hours
    assert_equal TimeEntryActivity.find(11), entry.activity
  end

  test "POST /time_entries.xml with issue_id should accept custom fields" do
    field = TimeEntryCustomField.create!(:name => 'Test', :field_format => 'string')

    assert_difference 'TimeEntry.count' do
      post '/time_entries.xml', {:time_entry => {
        :issue_id => '1', :spent_on => '2010-12-02', :hours => '3.5', :activity_id => '11', :custom_fields => [{:id => field.id.to_s, :value => 'accepted'}]
      }}, credentials('jsmith')
    end
    assert_response :created
    assert_equal 'application/xml', @response.content_type

    entry = TimeEntry.first(:order => 'id DESC')
    assert_equal 'accepted', entry.custom_field_value(field)
  end

  test "POST /time_entries.xml with project_id should create time entry" do
    assert_difference 'TimeEntry.count' do
      post '/time_entries.xml', {:time_entry => {:project_id => '1', :spent_on => '2010-12-02', :hours => '3.5', :activity_id => '11'}}, credentials('jsmith')
    end
    assert_response :created
    assert_equal 'application/xml', @response.content_type

    entry = TimeEntry.first(:order => 'id DESC')
    assert_equal 'jsmith', entry.user.login
    assert_nil entry.issue
    assert_equal Project.find(1), entry.project
    assert_equal Date.parse('2010-12-02'), entry.spent_on
    assert_equal 3.5, entry.hours
    assert_equal TimeEntryActivity.find(11), entry.activity
  end

  test "POST /time_entries.xml with invalid parameters should return errors" do
    assert_no_difference 'TimeEntry.count' do
      post '/time_entries.xml', {:time_entry => {:project_id => '1', :spent_on => '2010-12-02', :activity_id => '11'}}, credentials('jsmith')
    end
    assert_response :unprocessable_entity
    assert_equal 'application/xml', @response.content_type

    assert_tag 'errors', :child => {:tag => 'error', :content => "Hours can't be blank"}
  end

  test "PUT /time_entries/:id.xml with valid parameters should update time entry" do
    assert_no_difference 'TimeEntry.count' do
      put '/time_entries/2.xml', {:time_entry => {:comments => 'API Update'}}, credentials('jsmith')
    end
    assert_response :ok
    assert_equal '', @response.body
    assert_equal 'API Update', TimeEntry.find(2).comments
  end

  test "PUT /time_entries/:id.xml with invalid parameters should return errors" do
    assert_no_difference 'TimeEntry.count' do
      put '/time_entries/2.xml', {:time_entry => {:hours => '', :comments => 'API Update'}}, credentials('jsmith')
    end
    assert_response :unprocessable_entity
    assert_equal 'application/xml', @response.content_type

    assert_tag 'errors', :child => {:tag => 'error', :content => "Hours can't be blank"}
  end

  test "DELETE /time_entries/:id.xml should destroy time entry" do
    assert_difference 'TimeEntry.count', -1 do
      delete '/time_entries/2.xml', {}, credentials('jsmith')
    end
    assert_response :ok
    assert_equal '', @response.body
    assert_nil TimeEntry.find_by_id(2)
  end
end
