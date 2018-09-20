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

class Redmine::ApiTest::UsersTest < Redmine::ApiTest::Base
  fixtures :users, :email_addresses, :members, :member_roles, :roles, :projects

  test "GET /users.xml should return users" do
    get '/users.xml', :headers => credentials('admin')

    assert_response :success
    assert_equal 'application/xml', response.content_type
    assert_select 'users' do
      assert_select 'user', User.active.count
    end
  end

  test "GET /users.json should return users" do
    get '/users.json', :headers => credentials('admin')

    assert_response :success
    assert_equal 'application/json', response.content_type
    json = ActiveSupport::JSON.decode(response.body)
    assert json.key?('users')
    assert_equal User.active.count, json['users'].size
  end

  test "GET /users/:id.xml should return the user" do
    get '/users/2.xml'

    assert_response :success
    assert_select 'user id', :text => '2'
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
    assert_select 'user memberships', 1
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
    get '/users/current.xml', :headers => credentials('jsmith')

    assert_select 'user id', :text => '2'
  end

  test "GET /users/:id should not return login for other user" do
    get '/users/3.xml', :headers => credentials('jsmith')
    assert_response :success
    assert_select 'user login', 0
  end

  test "GET /users/:id should return login for current user" do
    get '/users/2.xml', :headers => credentials('jsmith')
    assert_response :success
    assert_select 'user login', :text => 'jsmith'
  end

  test "GET /users/:id should not return api_key for other user" do
    get '/users/3.xml', :headers => credentials('jsmith')
    assert_response :success
    assert_select 'user api_key', 0
  end

  test "GET /users/:id should return api_key for current user" do
    get '/users/2.xml', :headers => credentials('jsmith')
    assert_response :success
    assert_select 'user api_key', :text => User.find(2).api_key
  end

  test "GET /users/:id should not return status for standard user" do
    get '/users/3.xml', :headers => credentials('jsmith')
    assert_response :success
    assert_select 'user status', 0
  end

  test "GET /users/:id should return status for administrators" do
    get '/users/2.xml', :headers => credentials('admin')
    assert_response :success
    assert_select 'user status', :text => User.find(1).status.to_s
  end

  test "GET /users/:id should return admin status for current user" do
    get '/users/2.xml', :headers => credentials('jsmith')
    assert_response :success
    assert_select 'user admin', :text => 'false'
  end

  test "GET /users/:id should not return admin status for other user" do
    get '/users/3.xml', :headers => credentials('jsmith')
    assert_response :success
    assert_select 'user admin', 0
  end

  test "POST /users.xml with valid parameters should create the user" do
    assert_difference('User.count') do
      post '/users.xml',
        :params => {
          :user => {
            :login => 'foo', :firstname => 'Firstname', :lastname => 'Lastname',
            :mail => 'foo@example.net', :password => 'secret123',
            :mail_notification => 'only_assigned'
          }
        },
        :headers => credentials('admin')
    end

    user = User.order('id DESC').first
    assert_equal 'foo', user.login
    assert_equal 'Firstname', user.firstname
    assert_equal 'Lastname', user.lastname
    assert_equal 'foo@example.net', user.mail
    assert_equal 'only_assigned', user.mail_notification
    assert !user.admin?
    assert user.check_password?('secret123')

    assert_response :created
    assert_equal 'application/xml', @response.content_type
    assert_select 'user id', :text => user.id.to_s
  end

  test "POST /users.xml with generate_password should generate password" do
    assert_difference('User.count') do
      post '/users.xml',
        :params => {
          :user => {
            :login => 'foo', :firstname => 'Firstname', :lastname => 'Lastname',
            :mail => 'foo@example.net', :generate_password => 'true'
          }
        },
        :headers => credentials('admin')
    end

    user = User.order('id DESC').first
    assert user.hashed_password.present?
  end

  test "POST /users.json with valid parameters should create the user" do
    assert_difference('User.count') do
      post '/users.json',
        :params => {
          :user => {
            :login => 'foo', :firstname => 'Firstname', :lastname => 'Lastname',
            :mail => 'foo@example.net', :password => 'secret123',
            :mail_notification => 'only_assigned'
          }
        },
        :headers => credentials('admin')
    end

    user = User.order('id DESC').first
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
      post '/users.xml',
        :params => {
          :user =>{
            :login => 'foo', :lastname => 'Lastname', :mail => 'foo'
          }
        },
        :headers => credentials('admin')
    end

    assert_response :unprocessable_entity
    assert_equal 'application/xml', @response.content_type
    assert_select 'errors error', :text => "First name cannot be blank"
  end

  test "POST /users.json with with invalid parameters should return errors" do
    assert_no_difference('User.count') do
      post '/users.json',
        :params => {
          :user => {
            :login => 'foo', :lastname => 'Lastname', :mail => 'foo'
          }
        },
        :headers => credentials('admin')
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
      put '/users/2.xml',
        :params => {
          :user => {
            :login => 'jsmith', :firstname => 'John', :lastname => 'Renamed',
            :mail => 'jsmith@somenet.foo'
          }
        },
        :headers => credentials('admin')
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
      put '/users/2.json',
        :params => {
          :user => {
            :login => 'jsmith', :firstname => 'John', :lastname => 'Renamed',
            :mail => 'jsmith@somenet.foo'
          }
        },
        :headers => credentials('admin')
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
      put '/users/2.xml',
        :params => {
          :user => {
            :login => 'jsmith', :firstname => '', :lastname => 'Lastname',
            :mail => 'foo'
          }
        },
        :headers => credentials('admin')
    end

    assert_response :unprocessable_entity
    assert_equal 'application/xml', @response.content_type
    assert_select 'errors error', :text => "First name cannot be blank"
  end

  test "PUT /users/:id.json with invalid parameters" do
    assert_no_difference('User.count') do
      put '/users/2.json',
        :params => {
          :user => {
            :login => 'jsmith', :firstname => '', :lastname => 'Lastname',
            :mail => 'foo'
          }
        },
        :headers => credentials('admin')
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
      delete '/users/2.xml', :headers => credentials('admin')
    end

    assert_response :ok
    assert_equal '', @response.body
  end

  test "DELETE /users/:id.json should delete the user" do
    assert_difference('User.count', -1) do
      delete '/users/2.json', :headers => credentials('admin')
    end

    assert_response :ok
    assert_equal '', @response.body
  end
end
