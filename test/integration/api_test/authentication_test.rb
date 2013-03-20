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

class Redmine::ApiTest::AuthenticationTest < Redmine::ApiTest::Base
  fixtures :users

  def setup
    Setting.rest_api_enabled = '1'
  end

  def teardown
    Setting.rest_api_enabled = '0'
  end

  def test_api_request_should_not_use_user_session
    log_user('jsmith', 'jsmith')

    get '/users/current'
    assert_response :success

    get '/users/current.json'
    assert_response 401
  end

  def test_api_should_accept_switch_user_header_for_admin_user
    user = User.find(1)
    su = User.find(4)

    get '/users/current', {}, {'X-Redmine-API-Key' => user.api_key, 'X-Redmine-Switch-User' => su.login}
    assert_response :success
    assert_equal su, assigns(:user)
    assert_equal su, User.current
  end

  def test_api_should_respond_with_412_when_trying_to_switch_to_a_invalid_user
    get '/users/current', {}, {'X-Redmine-API-Key' => User.find(1).api_key, 'X-Redmine-Switch-User' => 'foobar'}
    assert_response 412
  end

  def test_api_should_respond_with_412_when_trying_to_switch_to_a_locked_user
    user = User.find(5)
    assert user.locked?

    get '/users/current', {}, {'X-Redmine-API-Key' => User.find(1).api_key, 'X-Redmine-Switch-User' => user.login}
    assert_response 412
  end

  def test_api_should_not_accept_switch_user_header_for_non_admin_user
    user = User.find(2)
    su = User.find(4)

    get '/users/current', {}, {'X-Redmine-API-Key' => user.api_key, 'X-Redmine-Switch-User' => su.login}
    assert_response :success
    assert_equal user, assigns(:user)
    assert_equal user, User.current
  end
end
