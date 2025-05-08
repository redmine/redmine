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

class Redmine::ApiTest::UsersTest < Redmine::ApiTest::Base
  test "GET /users.xml should return users" do
    users = User.active.order('login')
    users.last.update(twofa_scheme: 'totp')
    Redmine::Configuration.with 'avatar_server_url' => 'https://gravatar.com' do
      with_settings :gravatar_enabled => '1', :gravatar_default => 'mm' do
        get '/users.xml', :headers => credentials('admin')
      end
    end

    assert_response :success
    assert_equal 'application/xml', response.media_type
    assert_select 'users' do
      assert_select 'user', :count => users.size do |nodeset|
        nodeset.zip(users) do |user_element, user|
          assert_select user_element, 'id', :text => user.id.to_s
          assert_select user_element, 'updated_on', :text => user.updated_on.iso8601
          assert_select user_element, 'twofa_scheme', :text => user.twofa_scheme.to_s

          # No one has changed password.
          assert_select user_element, 'passwd_changed_on', :text => ''
          assert_select user_element, 'avatar_url', :text => %r|\Ahttps://gravatar.com/avatar/\h{64}\?default=mm|

          if user == users.last
            assert_select user_element, 'twofa_scheme', :text => 'totp'
          else
            assert_select user_element, 'twofa_scheme', :text => ''
          end
        end
      end
    end
  end

  test "GET /users.json should return users" do
    users = User.active.order('login')
    users.last.update(twofa_scheme: 'totp')
    get '/users.json', :headers => credentials('admin')

    assert_response :success
    assert_equal 'application/json', response.media_type
    json = ActiveSupport::JSON.decode(response.body)
    assert json.key?('users')

    users = User.active.order('login')
    assert_equal users.size, json['users'].size

    json['users'].zip(users) do |user_json, user|
      assert_equal user.id, user_json['id']
      assert_equal user.updated_on.iso8601, user_json['updated_on']
      assert_equal user.status, user_json['status']

      # No one has changed password.
      assert_nil user_json['passwd_changed_on']

      if user == users.last
        assert_equal 'totp', user_json['twofa_scheme']
      else
        assert_nil user_json['twofa_scheme']
      end
    end
  end

  test "GET /users.json with legacy filter params" do
    get '/users.json', headers: credentials('admin'), params: { status: 3 }
    assert_response :success
    json = ActiveSupport::JSON.decode(response.body)
    assert json.key?('users')
    users = User.where(status: 3)
    assert_equal users.size, json['users'].size

    get '/users.json', headers: credentials('admin'), params: { status: '*' }
    assert_response :success
    json = ActiveSupport::JSON.decode(response.body)
    assert json.key?('users')
    users = User.logged
    assert_equal users.size, json['users'].size

    get '/users.json', headers: credentials('admin'), params: { name: 'jsmith' }
    assert_response :success
    json = ActiveSupport::JSON.decode(response.body)
    assert json.key?('users')
    assert_equal 1, json['users'].size
    assert_equal 2, json['users'][0]['id']

    get '/users.json', headers: credentials('admin'), params: { group_id: '10' }
    assert_response :success
    json = ActiveSupport::JSON.decode(response.body)
    assert json.key?('users')
    assert_equal 1, json['users'].size
    assert_equal 8, json['users'][0]['id']

    # there should be an implicit filter for status = 1
    User.where(id: [2, 8]).update_all status: 3

    get '/users.json', headers: credentials('admin'), params: { name: 'jsmith' }
    assert_response :success
    json = ActiveSupport::JSON.decode(response.body)
    assert json.key?('users')
    assert_equal 0, json['users'].size

    get '/users.json', headers: credentials('admin'), params: { group_id: '10' }
    assert_response :success
    json = ActiveSupport::JSON.decode(response.body)
    assert json.key?('users')
    assert_equal 0, json['users'].size
  end

  test "GET /users.json with include=auth_source" do
    user = User.find(2)
    user.update(:auth_source_id => 1)
    get '/users.json?include=auth_source', :headers => credentials('admin')

    json = ActiveSupport::JSON.decode(response.body)
    assert json.key?('users')

    json['users'].each do |user_json|
      if user_json['id'] == user.id
        assert_kind_of Hash, user_json['auth_source']
        assert_equal user.auth_source.id, user_json['auth_source']['id']
        assert_equal user.auth_source.name, user_json['auth_source']['name']
      else
        assert_nil user_json['auth_source']
      end
    end
  end

  test "GET /users.json with short filters" do
    get '/users.json', headers: credentials('admin'), params: { status: "1|3" }
    assert_response :success
    json = ActiveSupport::JSON.decode(response.body)
    assert json.key?('users')
    users = User.where(status: [1, 3])
    assert_equal users.size, json['users'].size
  end

  test "GET /users/:id.xml should return the user" do
    Redmine::Configuration.with 'avatar_server_url' => 'https://gravatar.com' do
      with_settings :gravatar_enabled => '1', :gravatar_default => 'robohash' do
        get '/users/2.xml'
      end
    end

    assert_response :success
    assert_select 'user id', :text => '2'
    assert_select 'user updated_on', :text => Time.zone.parse('2006-07-19T20:42:15Z').iso8601
    assert_select 'user passwd_changed_on', :text => ''
    assert_select 'user avatar_url', :text => %r|\Ahttps://gravatar.com/avatar/\h{64}\?default=robohash|
  end

  test "GET /users/:id.xml should not return avatar_url when not set email address" do
    user = User.find(2)
    user.email_addresses.delete_all
    assert_equal 'jsmith', user.login
    assert_nil user.mail

    Redmine::Configuration.with 'avatar_server_url' => 'https://gravatar.com' do
      with_settings :gravatar_enabled => '1', :gravatar_default => 'robohash' do
        get '/users/2.xml'
      end
    end

    assert_response :success
    assert_select 'user id', :text => '2'
    assert_select 'user login', :text => 'jsmith'
    assert_select 'user avatar_url', :count => 0
  end

  test "GET /users/:id.json should return the user" do
    get '/users/2.json'

    assert_response :success
    json = ActiveSupport::JSON.decode(response.body)
    assert_kind_of Hash, json
    assert_kind_of Hash, json['user']
    assert_equal 2, json['user']['id']
    assert_equal Time.zone.parse('2006-07-19T20:42:15Z').iso8601, json['user']['updated_on']
    assert_nil json['user']['passwd_changed_on']
    assert_nil json['user']['twofa_scheme']
    assert_nil json['user']['auth_source']
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

  test "GET /users/:id.json with include=auth_source should include auth_source for administrators" do
    user = User.find(2)
    user.update(:auth_source_id => 1)
    get '/users/2.json?include=auth_source', :headers => credentials('admin')

    assert_response :success
    json = ActiveSupport::JSON.decode(response.body)

    assert_equal user.auth_source.id, json['user']['auth_source']['id']
    assert_equal user.auth_source.name, json['user']['auth_source']['name']
  end

  test "GET /users/:id.json without include=auth_source should not include auth_source" do
    user = User.find(2)
    user.update(:auth_source_id => 1)
    get '/users/2.json', :headers => credentials('admin')

    assert_response :success
    json = ActiveSupport::JSON.decode(response.body)

    assert_response :success
    assert_nil json['user']['auth_source']
  end

  test "GET /users/:id.json should not include auth_source for standard user" do
    user = User.find(2)
    user.update(:auth_source_id => 1)
    get '/users/2.json?include=auth_source', :headers => credentials('jsmith')

    assert_response :success
    json = ActiveSupport::JSON.decode(response.body)

    assert_equal user.id, json['user']['id']
    assert_nil json['user']['auth_source']
  end

  test "GET /users/current.xml should require authentication" do
    get '/users/current.xml'

    assert_response :unauthorized
  end

  test "GET /users/current.xml should return current user" do
    get '/users/current.xml', :headers => credentials('jsmith')

    assert_select 'user id', :text => '2'
  end

  test "GET /users/:id should return login for visible user" do
    get '/users/3.xml', :headers => credentials('jsmith')
    assert_response :success
    assert_select 'user login', :text => 'dlopper'
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
    assert_select 'user status', :text => User.find(2).status.to_s
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

  test "GET /users/:id should not return twofa_scheme for standard user" do
    # User and password authentication is disabled when twofa is enabled
    # Use token authentication
    user = User.find(2)
    token = Token.create!(:user => user, :action => 'api')
    user.update(twofa_scheme: 'totp')

    get '/users/3.xml', :headers => credentials(token.value, 'X')
    assert_response :success
    assert_select 'twofa_scheme', 0
  end

  test "GET /users/:id should return twofa_scheme for administrators" do
    User.find(2).update(twofa_scheme: 'totp')
    get '/users/2.xml', :headers => credentials('admin')
    assert_response :success
    assert_select 'twofa_scheme', :text => 'totp'
  end

  test "POST /users.xml with valid parameters should create the user" do
    assert_difference('User.count') do
      post(
        '/users.xml',
        :params => {
          :user => {
            :login => 'foo', :firstname => 'Firstname', :lastname => 'Lastname',
            :mail => 'foo@example.net', :password => 'secret123',
            :mail_notification => 'only_assigned'
          }
        },
        :headers => credentials('admin'))
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
    assert_equal 'application/xml', @response.media_type
    assert_select 'user id', :text => user.id.to_s
  end

  test "POST /users.xml with generate_password should generate password" do
    assert_difference('User.count') do
      post(
        '/users.xml',
        :params => {
          :user => {
            :login => 'foo', :firstname => 'Firstname', :lastname => 'Lastname',
            :mail => 'foo@example.net', :generate_password => 'true'
          }
        },
        :headers => credentials('admin'))
    end

    user = User.order('id DESC').first
    assert user.hashed_password.present?
  end

  test "POST /users.json with valid parameters should create the user" do
    assert_difference('User.count') do
      post(
        '/users.json',
        :params => {
          :user => {
            :login => 'foo', :firstname => 'Firstname', :lastname => 'Lastname',
            :mail => 'foo@example.net', :password => 'secret123',
            :mail_notification => 'only_assigned'
          }
        },
        :headers => credentials('admin'))
    end

    user = User.order('id DESC').first
    assert_equal 'foo', user.login
    assert_equal 'Firstname', user.firstname
    assert_equal 'Lastname', user.lastname
    assert_equal 'foo@example.net', user.mail
    assert !user.admin?

    assert_response :created
    assert_equal 'application/json', @response.media_type
    json = ActiveSupport::JSON.decode(response.body)
    assert_kind_of Hash, json
    assert_kind_of Hash, json['user']
    assert_equal user.id, json['user']['id']
  end

  test "POST /users.xml with with invalid parameters should return errors" do
    assert_no_difference('User.count') do
      post(
        '/users.xml',
        :params => {
          :user =>{
            :login => 'foo', :lastname => 'Lastname', :mail => 'foo'
          }
        },
        :headers => credentials('admin'))
    end

    assert_response :unprocessable_content
    assert_equal 'application/xml', @response.media_type
    assert_select 'errors error', :text => "First name cannot be blank"
  end

  test "POST /users.json with with invalid parameters should return errors" do
    assert_no_difference('User.count') do
      post(
        '/users.json',
        :params => {
          :user => {
            :login => 'foo', :lastname => 'Lastname', :mail => 'foo'
          }
        },
        :headers => credentials('admin'))
    end

    assert_response :unprocessable_content
    assert_equal 'application/json', @response.media_type
    json = ActiveSupport::JSON.decode(response.body)
    assert_kind_of Hash, json
    assert json.has_key?('errors')
    assert_kind_of Array, json['errors']
  end

  test "PUT /users/:id.xml with valid parameters should update the user" do
    assert_no_difference('User.count') do
      put(
        '/users/2.xml',
        :params => {
          :user => {
            :login => 'jsmith', :firstname => 'John', :lastname => 'Renamed',
            :mail => 'jsmith@somenet.foo'
          }
        },
        :headers => credentials('admin'))
    end

    user = User.find(2)
    assert_equal 'jsmith', user.login
    assert_equal 'John', user.firstname
    assert_equal 'Renamed', user.lastname
    assert_equal 'jsmith@somenet.foo', user.mail
    assert !user.admin?

    assert_response :no_content
    assert_equal '', @response.body
  end

  test "PUT /users/:id.json with valid parameters should update the user" do
    assert_no_difference('User.count') do
      put(
        '/users/2.json',
        :params => {
          :user => {
            :login => 'jsmith', :firstname => 'John', :lastname => 'Renamed',
            :mail => 'jsmith@somenet.foo'
          }
        },
        :headers => credentials('admin'))
    end

    user = User.find(2)
    assert_equal 'jsmith', user.login
    assert_equal 'John', user.firstname
    assert_equal 'Renamed', user.lastname
    assert_equal 'jsmith@somenet.foo', user.mail
    assert !user.admin?

    assert_response :no_content
    assert_equal '', @response.body
  end

  test "PUT /users/:id.xml with invalid parameters" do
    assert_no_difference('User.count') do
      put(
        '/users/2.xml',
        :params => {
          :user => {
            :login => 'jsmith', :firstname => '', :lastname => 'Lastname',
            :mail => 'foo'
          }
        },
        :headers => credentials('admin'))
    end

    assert_response :unprocessable_content
    assert_equal 'application/xml', @response.media_type
    assert_select 'errors error', :text => "First name cannot be blank"
  end

  test "PUT /users/:id.json with invalid parameters" do
    assert_no_difference('User.count') do
      put(
        '/users/2.json',
        :params => {
          :user => {
            :login => 'jsmith', :firstname => '', :lastname => 'Lastname',
            :mail => 'foo'
          }
        },
        :headers => credentials('admin'))
    end

    assert_response :unprocessable_content
    assert_equal 'application/json', @response.media_type
    json = ActiveSupport::JSON.decode(response.body)
    assert_kind_of Hash, json
    assert json.has_key?('errors')
    assert_kind_of Array, json['errors']
  end

  test "DELETE /users/:id.xml should delete the user" do
    assert_difference('User.count', -1) do
      delete '/users/2.xml', :headers => credentials('admin')
    end

    assert_response :no_content
    assert_equal '', @response.body
  end

  test "DELETE /users/:id.json should delete the user" do
    assert_difference('User.count', -1) do
      delete '/users/2.json', :headers => credentials('admin')
    end

    assert_response :no_content
    assert_equal '', @response.body
  end
end
