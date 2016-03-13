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

require File.expand_path('../../../test_helper', __FILE__)

class Redmine::ApiTest::VersionsTest < Redmine::ApiTest::Base
  fixtures :projects, :trackers, :issue_statuses, :issues,
           :enumerations, :users, :issue_categories,
           :projects_trackers,
           :roles,
           :member_roles,
           :members,
           :enabled_modules,
           :versions

  test "GET /projects/:project_id/versions.xml should return project versions" do
    get '/projects/1/versions.xml'

    assert_response :success
    assert_equal 'application/xml', @response.content_type

    assert_select 'versions[type=array] version id', :text => '2' do
      assert_select '~ name', :text => '1.0'
    end
  end

  test "POST /projects/:project_id/versions.xml should create the version" do
    assert_difference 'Version.count' do
      post '/projects/1/versions.xml', {:version => {:name => 'API test'}}, credentials('jsmith')
    end

    version = Version.order('id DESC').first
    assert_equal 'API test', version.name

    assert_response :created
    assert_equal 'application/xml', @response.content_type
    assert_select 'version id', :text => version.id.to_s
  end

  test "POST /projects/:project_id/versions.xml should create the version with due date" do
    assert_difference 'Version.count' do
      post '/projects/1/versions.xml', {:version => {:name => 'API test', :due_date => '2012-01-24'}}, credentials('jsmith')
    end

    version = Version.order('id DESC').first
    assert_equal 'API test', version.name
    assert_equal Date.parse('2012-01-24'), version.due_date

    assert_response :created
    assert_equal 'application/xml', @response.content_type
    assert_select 'version id', :text => version.id.to_s
  end

  test "POST /projects/:project_id/versions.xml should create the version with custom fields" do
    field = VersionCustomField.generate!

    assert_difference 'Version.count' do
      post '/projects/1/versions.xml', {
          :version => {
            :name => 'API test',
            :custom_fields => [
              {'id' => field.id.to_s, 'value' => 'Some value'}
            ]
          }
        }, credentials('jsmith')
    end

    version = Version.order('id DESC').first
    assert_equal 'API test', version.name
    assert_equal 'Some value', version.custom_field_value(field)

    assert_response :created
    assert_equal 'application/xml', @response.content_type
    assert_select 'version>custom_fields>custom_field[id=?]>value', field.id.to_s, 'Some value'
  end

  test "POST /projects/:project_id/versions.xml with failure should return the errors" do
    assert_no_difference('Version.count') do
      post '/projects/1/versions.xml', {:version => {:name => ''}}, credentials('jsmith')
    end

    assert_response :unprocessable_entity
    assert_select 'errors error', :text => "Name cannot be blank"
  end

  test "GET /versions/:id.xml should return the version" do
    get '/versions/2.xml'

    assert_response :success
    assert_equal 'application/xml', @response.content_type
    assert_select 'version' do
      assert_select 'id', :text => '2'
      assert_select 'name', :text => '1.0'
      assert_select 'sharing', :text => 'none'
    end
  end

  test "PUT /versions/:id.xml should update the version" do
    put '/versions/2.xml', {:version => {:name => 'API update'}}, credentials('jsmith')

    assert_response :ok
    assert_equal '', @response.body
    assert_equal 'API update', Version.find(2).name
  end

  test "DELETE /versions/:id.xml should destroy the version" do
    assert_difference 'Version.count', -1 do
      delete '/versions/3.xml', {}, credentials('jsmith')
    end

    assert_response :ok
    assert_equal '', @response.body
    assert_nil Version.find_by_id(3)
  end
end
