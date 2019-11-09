# frozen_string_literal: true

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

require File.expand_path('../../../test_helper', __FILE__)

class Redmine::ApiTest::MyTest < Redmine::ApiTest::Base
  fixtures :users, :email_addresses, :members, :member_roles, :roles, :projects

  test "GET /my/account.json should return user" do
    assert Setting.rest_api_enabled?
    get '/my/account.json', :headers => credentials('dlopper', 'foo')

    assert_response :success
    assert_equal 'application/json', response.content_type
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
    assert_response :unprocessable_entity
    assert_equal 'application/xml', @response.content_type
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
    assert_response :unprocessable_entity
    assert_equal 'application/json', @response.content_type
    json = ActiveSupport::JSON.decode(response.body)
    assert_kind_of Hash, json
    assert json.has_key?('errors')
    assert_kind_of Array, json['errors']
  end
end
