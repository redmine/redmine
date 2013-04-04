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

class Redmine::ApiTest::DisabledRestApiTest < Redmine::ApiTest::Base
  fixtures :projects, :trackers, :issue_statuses, :issues,
           :enumerations, :users, :issue_categories,
           :projects_trackers,
           :roles,
           :member_roles,
           :members,
           :enabled_modules

  def setup
    Setting.rest_api_enabled = '0'
    Setting.login_required = '1'
  end

  def teardown
    Setting.rest_api_enabled = '1'
    Setting.login_required = '0'
  end

  def test_with_a_valid_api_token
    @user = User.generate!
    @token = Token.create!(:user => @user, :action => 'api')

    get "/news.xml?key=#{@token.value}"
    assert_response :unauthorized
    assert_equal User.anonymous, User.current

    get "/news.json?key=#{@token.value}"
    assert_response :unauthorized
    assert_equal User.anonymous, User.current
  end

  def test_with_valid_username_password_http_authentication
    @user = User.generate! do |user|
      user.password = 'my_password'
    end

    get "/news.xml", nil, credentials(@user.login, 'my_password')
    assert_response :unauthorized
    assert_equal User.anonymous, User.current

    get "/news.json", nil, credentials(@user.login, 'my_password')
    assert_response :unauthorized
    assert_equal User.anonymous, User.current
  end

  def test_with_valid_token_http_authentication
    @user = User.generate!
    @token = Token.create!(:user => @user, :action => 'api')

    get "/news.xml", nil, credentials(@token.value, 'X')
    assert_response :unauthorized
    assert_equal User.anonymous, User.current

    get "/news.json", nil, credentials(@token.value, 'X')
    assert_response :unauthorized
    assert_equal User.anonymous, User.current
  end
end
