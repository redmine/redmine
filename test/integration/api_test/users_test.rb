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

class Redmine::ApiTest::UsersTest < Redmine::ApiTest::Base
  fixtures :users, :members, :member_roles, :roles, :projects

  def setup
    Setting.rest_api_enabled = '1'
  end

  should_allow_api_authentication(:get, "/users.xml")
  should_allow_api_authentication(:get, "/users.json")
  should_allow_api_authentication(:post,
    '/users.xml',
     {:user => {
        :login => 'foo', :firstname => 'Firstname', :lastname => 'Lastname',
        :mail => 'foo@example.net', :password => 'secret123'
      }},
    {:success_code => :created})
  should_allow_api_authentication(:post,
    '/users.json',
    {:user => {
       :login => 'foo', :firstname => 'Firstname', :lastname => 'Lastname',
       :mail => 'foo@example.net'
    }},
    {:success_code => :created})
  should_allow_api_authentication(:put,
    '/users/2.xml',
    {:user => {
        :login => 'jsmith', :firstname => 'John', :lastname => 'Renamed',
        :mail => 'jsmith@somenet.foo'
    }},
    {:success_code => :ok})
  should_allow_api_authentication(:put,
    '/users/2.json',
    {:user => {
        :login => 'jsmith', :firstname => 'John', :lastname => 'Renamed',
        :mail => 'jsmith@somenet.foo'
    }},
    {:success_code => :ok})
  should_allow_api_authentication(:delete,
    '/users/2.xml',
    {},
    {:success_code => :ok})
  should_allow_api_authentication(:delete,
    '/users/2.xml',
    {},
    {:success_code => :ok})

  test "GET /users/:id.xml should return the user" do
    get '/users/2.xml'

    assert_response :success
    assert_tag :tag => 'user',
      :child => {:tag => 'id', :content => '2'}
  end

  test "GET /users/:id.json should return the user" do
    get '/users/2.json'

    assert_response :success
    json = ActiveSupport::JSON.decode(response.body)
    assert_kind_of Hash, json
    assert_kind_of Hash, json['user']
    assert_equal 2, json['user']['id']
  end

  test "GET /users/:id.xml with include=memberships should include memberships" do
    get '/users/2.xml?include=memberships'

    assert_response :success
    assert_tag :tag => 'memberships',
      :parent => {:tag => 'user'},
      :children => {:count => 1}
  end

  test "GET /users/:id.json with include=memberships should include memberships" do
    get '/users/2.json?include=memberships'

    assert_response :success
    json = ActiveSupport::JSON.decode(response.body)
    assert_kind_of Array, json['user']['memberships']
    assert_equal [{
      "id"=>1,
      "project"=>{"name"=>"eCookbook", "id"=>1},
      "roles"=>[{"name"=>"Manager", "id"=>1}]
    }], json['user']['memberships']
  end

  test "GET /users/current.xml should require authentication" do
    get '/users/current.xml'

    assert_response 401
  end

  test "GET /users/current.xml should return current user" do
    get '/users/current.xml', {}, credentials('jsmith')

    assert_tag :tag => 'user',
      :child => {:tag => 'id', :content => '2'}
  end

  test "GET /users/:id should not return login for other user" do
    get '/users/3.xml', {}, credentials('jsmith')
    assert_response :success
    assert_no_tag 'user', :child => {:tag => 'login'}
  end

  test "GET /users/:id should return login for current user" do
    get '/users/2.xml', {}, credentials('jsmith')
    assert_response :success
    assert_tag 'user', :child => {:tag => 'login', :content => 'jsmith'}
  end

  test "GET /users/:id should not return api_key for other user" do
    get '/users/3.xml', {}, credentials('jsmith')
    assert_response :success
    assert_no_tag 'user', :child => {:tag => 'api_key'}
  end

  test "GET /users/:id should return api_key for current user" do
    get '/users/2.xml', {}, credentials('jsmith')
    assert_response :success
    assert_tag 'user', :child => {:tag => 'api_key', :content => User.find(2).api_key}
  end

  test "GET /users/:id should not return status for standard user" do
    get '/users/3.xml', {}, credentials('jsmith')
    assert_response :success
    assert_no_tag 'user', :child => {:tag => 'status'}
  end

  test "GET /users/:id should return status for administrators" do
    get '/users/2.xml', {}, credentials('admin')
    assert_response :success
    assert_tag 'user', :child => {:tag => 'status', :content => User.find(1).status.to_s}
  end

  test "POST /users.xml with valid parameters should create the user" do
    assert_difference('User.count') do
      post '/users.xml', {
        :user => {
          :login => 'foo', :firstname => 'Firstname', :lastname => 'Lastname',
          :mail => 'foo@example.net', :password => 'secret123',
          :mail_notification => 'only_assigned'}
        },
        credentials('admin')
    end

    user = User.first(:order => 'id DESC')
    assert_equal 'foo', user.login
    assert_equal 'Firstname', user.firstname
    assert_equal 'Lastname', user.lastname
    assert_equal 'foo@example.net', user.mail
    assert_equal 'only_assigned', user.mail_notification
    assert !user.admin?
    assert user.check_password?('secret123')

    assert_response :created
    assert_equal 'application/xml', @response.content_type
    assert_tag 'user', :child => {:tag => 'id', :content => user.id.to_s}
  end

  test "POST /users.json with valid parameters should create the user" do
    assert_difference('User.count') do
      post '/users.json', {
        :user => {
          :login => 'foo', :firstname => 'Firstname', :lastname => 'Lastname',
          :mail => 'foo@example.net', :password => 'secret123',
          :mail_notification => 'only_assigned'}
        },
        credentials('admin')
    end

    user = User.first(:order => 'id DESC')
    assert_equal 'foo', user.login
    assert_equal 'Firstname', user.firstname
    assert_equal 'Lastname', user.lastname
    assert_equal 'foo@example.net', user.mail
    assert !user.admin?

    assert_response :created
    assert_equal 'application/json', @response.content_type
    json = ActiveSupport::JSON.decode(response.body)
    assert_kind_of Hash, json
    assert_kind_of Hash, json['user']
    assert_equal user.id, json['user']['id']
  end

  test "POST /users.xml with with invalid parameters should return errors" do
    assert_no_difference('User.count') do
      post '/users.xml', {:user => {:login => 'foo', :lastname => 'Lastname', :mail => 'foo'}}, credentials('admin')
    end

    assert_response :unprocessable_entity
    assert_equal 'application/xml', @response.content_type
    assert_tag 'errors', :child => {
                           :tag => 'error',
                           :content => "First name can't be blank"
                         }
  end

  test "POST /users.json with with invalid parameters should return errors" do
    assert_no_difference('User.count') do
      post '/users.json', {:user => {:login => 'foo', :lastname => 'Lastname', :mail => 'foo'}}, credentials('admin')
    end

    assert_response :unprocessable_entity
    assert_equal 'application/json', @response.content_type
    json = ActiveSupport::JSON.decode(response.body)
    assert_kind_of Hash, json
    assert json.has_key?('errors')
    assert_kind_of Array, json['errors']
  end

  test "PUT /users/:id.xml with valid parameters should update the user" do
    assert_no_difference('User.count') do
      put '/users/2.xml', {
        :user => {
          :login => 'jsmith', :firstname => 'John', :lastname => 'Renamed',
          :mail => 'jsmith@somenet.foo'}
        },
        credentials('admin')
    end

    user = User.find(2)
    assert_equal 'jsmith', user.login
    assert_equal 'John', user.firstname
    assert_equal 'Renamed', user.lastname
    assert_equal 'jsmith@somenet.foo', user.mail
    assert !user.admin?

    assert_response :ok
    assert_equal '', @response.body
  end

  test "PUT /users/:id.json with valid parameters should update the user" do
    assert_no_difference('User.count') do
      put '/users/2.json', {
        :user => {
          :login => 'jsmith', :firstname => 'John', :lastname => 'Renamed',
          :mail => 'jsmith@somenet.foo'}
        },
        credentials('admin')
    end

    user = User.find(2)
    assert_equal 'jsmith', user.login
    assert_equal 'John', user.firstname
    assert_equal 'Renamed', user.lastname
    assert_equal 'jsmith@somenet.foo', user.mail
    assert !user.admin?

    assert_response :ok
    assert_equal '', @response.body
  end

  test "PUT /users/:id.xml with invalid parameters" do
    assert_no_difference('User.count') do
      put '/users/2.xml', {
        :user => {
          :login => 'jsmith', :firstname => '', :lastname => 'Lastname',
          :mail => 'foo'}
        },
        credentials('admin')
    end

    assert_response :unprocessable_entity
    assert_equal 'application/xml', @response.content_type
    assert_tag 'errors', :child => {
                           :tag => 'error',
                           :content => "First name can't be blank"
                          }
  end

  test "PUT /users/:id.json with invalid parameters" do
    assert_no_difference('User.count') do
      put '/users/2.json', {
        :user => {
          :login => 'jsmith', :firstname => '', :lastname => 'Lastname',
          :mail => 'foo'}
        },
        credentials('admin')
    end

    assert_response :unprocessable_entity
    assert_equal 'application/json', @response.content_type
    json = ActiveSupport::JSON.decode(response.body)
    assert_kind_of Hash, json
    assert json.has_key?('errors')
    assert_kind_of Array, json['errors']
  end

  test "DELETE /users/:id.xml should delete the user" do
    assert_difference('User.count', -1) do
      delete '/users/2.xml', {}, credentials('admin')
    end

    assert_response :ok
    assert_equal '', @response.body
  end

  test "DELETE /users/:id.json should delete the user" do
    assert_difference('User.count', -1) do
      delete '/users/2.json', {}, credentials('admin')
    end

    assert_response :ok
    assert_equal '', @response.body
  end
end
