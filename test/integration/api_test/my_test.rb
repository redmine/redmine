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

require_relative '../../test_helper'

class Redmine::ApiTest::MyTest < Redmine::ApiTest::Base
  test "GET /my/account.json should return user" do
    assert Setting.rest_api_enabled?
    get '/my/account.json', :headers => credentials('dlopper', 'foo')

    assert_response :success
    assert_equal 'application/json', response.media_type
    json = ActiveSupport::JSON.decode(response.body)
    assert json.key?('user')
    assert_equal 'dlopper', json['user']['login']
  end

  test "PUT /my/account.xml with valid parameters should update the user" do
    put(
      '/my/account.xml',
      :params => {
        :user => {
          :firstname => 'Dave', :lastname => 'Renamed',
          :mail => 'dave@somenet.foo'
        }
      },
      :headers => credentials('dlopper', 'foo'))
    assert_response :no_content
    assert_equal '', @response.body

    assert user = User.find_by_lastname('Renamed')
    assert_equal 'Dave', user.firstname
    assert_equal 'Renamed', user.lastname
    assert_equal 'dave@somenet.foo', user.mail
    refute user.admin?
  end

  test "PUT /my/account.json with valid parameters should update the user" do
    put(
      '/my/account.xml',
      :params => {
        :user => {
          :firstname => 'Dave', :lastname => 'Renamed',
          :mail => 'dave@somenet.foo'
        }
      },
      :headers => credentials('dlopper', 'foo'))
    assert_response :no_content
    assert_equal '', @response.body
    assert user = User.find_by_lastname('Renamed')
    assert_equal 'Dave', user.firstname
    assert_equal 'Renamed', user.lastname
    assert_equal 'dave@somenet.foo', user.mail
    refute user.admin?
  end

  test "PUT /my/account.xml with invalid parameters" do
    put(
      '/my/account.xml',
      :params => {
        :user => {
          :login => 'dlopper', :firstname => '', :lastname => 'Lastname'
        }
      },
      :headers => credentials('dlopper', 'foo'))
    assert_response :unprocessable_content
    assert_equal 'application/xml', @response.media_type
    assert_select 'errors error', :text => "First name cannot be blank"
  end

  test "PUT /my/account.json with invalid parameters" do
    put(
      '/my/account.json',
      :params => {
        :user => {
          :login => 'dlopper', :firstname => '', :lastname => 'Lastname'
        }
      },
      :headers => credentials('dlopper', 'foo'))
    assert_response :unprocessable_content
    assert_equal 'application/json', @response.media_type
    json = ActiveSupport::JSON.decode(response.body)
    assert_kind_of Hash, json
    assert json.has_key?('errors')
    assert_kind_of Array, json['errors']
  end

  test "GET /my/account.json authenticated via OAuth should not disclose the api_key" do
    application = Doorkeeper::Application.create!(
      :name => 'Test App',
      :redirect_uri => 'http://localhost/callback',
      :scopes => 'view_issues'
    )
    token = Doorkeeper::AccessToken.create!(
      :application_id => application.id,
      :resource_owner_id => 2,
      :scopes => 'view_issues',
      :expires_in => 7200
    )

    get '/my/account.json', :headers => {'Authorization' => "Bearer #{token.plaintext_token}"}

    assert_response :success
    json = ActiveSupport::JSON.decode(response.body)
    assert_equal 'jsmith', json['user']['login']
    assert_not(
      json['user'].key?('api_key'),
      "OAuth-authenticated request must not disclose the permanent api_key"
    )
  end

  test "GET /my/account.json authenticated via API key should disclose the api_key" do
    key = User.find(2).api_key

    get '/my/account.json', :headers => {'X-Redmine-API-Key' => key}

    assert_response :success
    json = ActiveSupport::JSON.decode(response.body)
    assert_equal 'jsmith', json['user']['login']
    assert_equal key, json['user']['api_key']
  end
end
