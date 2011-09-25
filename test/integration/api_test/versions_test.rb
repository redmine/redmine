# Redmine - project management software
# Copyright (C) 2006-2011  Jean-Philippe Lang
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

class ApiTest::VersionsTest < ActionController::IntegrationTest
  fixtures :projects, :trackers, :issue_statuses, :issues,
           :enumerations, :users, :issue_categories,
           :projects_trackers,
           :roles,
           :member_roles,
           :members,
           :enabled_modules,
           :workflows,
           :versions

  def setup
    Setting.rest_api_enabled = '1'
  end

  context "/projects/:project_id/versions" do
    context "GET" do
      should "return project versions" do
        get '/projects/1/versions.xml'

        assert_response :success
        assert_equal 'application/xml', @response.content_type
        assert_tag :tag => 'versions',
          :attributes => {:type => 'array'},
          :child => {
            :tag => 'version',
            :child => {
              :tag => 'id',
              :content => '2',
              :sibling => {
                :tag => 'name',
                :content => '1.0'
              }
            }
          }
      end
    end

    context "POST" do
      should "create the version" do
        assert_difference 'Version.count' do
          post '/projects/1/versions.xml', {:version => {:name => 'API test'}}, :authorization => credentials('jsmith')
        end

        version = Version.first(:order => 'id DESC')
        assert_equal 'API test', version.name

        assert_response :created
        assert_equal 'application/xml', @response.content_type
        assert_tag 'version', :child => {:tag => 'id', :content => version.id.to_s}
      end

      context "with failure" do
        should "return the errors" do
          assert_no_difference('Version.count') do
            post '/projects/1/versions.xml', {:version => {:name => ''}}, :authorization => credentials('jsmith')
          end

          assert_response :unprocessable_entity
          assert_tag :errors, :child => {:tag => 'error', :content => "Name can't be blank"}
        end
      end
    end
  end

  context "/versions/:id" do
    context "GET" do
      should "return the version" do
        get '/versions/2.xml'

        assert_response :success
        assert_equal 'application/xml', @response.content_type
        assert_tag 'version',
          :child => {
            :tag => 'id',
            :content => '2',
            :sibling => {
              :tag => 'name',
              :content => '1.0'
            }
          }
      end
    end

    context "PUT" do
      should "update the version" do
        put '/versions/2.xml', {:version => {:name => 'API update'}}, :authorization => credentials('jsmith')

        assert_response :ok
        assert_equal 'API update', Version.find(2).name
      end
    end

    context "DELETE" do
      should "destroy the version" do
        assert_difference 'Version.count', -1 do
          delete '/versions/3.xml', {}, :authorization => credentials('jsmith')
        end

        assert_response :ok
        assert_nil Version.find_by_id(3)
      end
    end
  end

  def credentials(user, password=nil)
    ActionController::HttpAuthentication::Basic.encode_credentials(user, password || user)
  end
end
