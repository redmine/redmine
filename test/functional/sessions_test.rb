# Redmine - project management software
# Copyright (C) 2006-2015  Jean-Philippe Lang
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

require File.expand_path('../../test_helper', __FILE__)

class SessionStartTest < ActionController::TestCase
  tests AccountController

  fixtures :users

  def test_login_should_set_session_timestamps
    post :login, :username => 'jsmith', :password => 'jsmith'
    assert_response 302
    assert_equal 2, session[:user_id]
    assert_not_nil session[:ctime]
    assert_not_nil session[:atime]
  end
end

class SessionsTest < ActionController::TestCase
  include Redmine::I18n
  tests WelcomeController

  fixtures :users, :email_addresses

  def test_atime_from_user_session_should_be_updated
    created = 2.hours.ago.utc.to_i
    get :index, {}, {:user_id => 2, :ctime => created, :atime => created}
    assert_response :success
    assert_equal created, session[:ctime]
    assert_not_equal created, session[:atime]
    assert session[:atime] > created
  end

  def test_user_session_should_not_be_reset_if_lifetime_and_timeout_disabled
    with_settings :session_lifetime => '0', :session_timeout => '0' do
      get :index, {}, {:user_id => 2}
      assert_response :success
    end
  end

  def test_user_session_without_ctime_should_be_reset_if_lifetime_enabled
    with_settings :session_lifetime => '720' do
      get :index, {}, {:user_id => 2}
      assert_redirected_to 'http://test.host/login?back_url=http%3A%2F%2Ftest.host%2F'
    end
  end

  def test_user_session_with_expired_ctime_should_be_reset_if_lifetime_enabled
    with_settings :session_timeout => '720' do
      get :index, {}, {:user_id => 2, :atime => 2.days.ago.utc.to_i}
      assert_redirected_to 'http://test.host/login?back_url=http%3A%2F%2Ftest.host%2F'
    end
  end

  def test_user_session_with_valid_ctime_should_not_be_reset_if_lifetime_enabled
    with_settings :session_timeout => '720' do
      get :index, {}, {:user_id => 2, :atime => 3.hours.ago.utc.to_i}
      assert_response :success
    end
  end

  def test_user_session_without_atime_should_be_reset_if_timeout_enabled
    with_settings :session_timeout => '60' do
      get :index, {}, {:user_id => 2}
      assert_redirected_to 'http://test.host/login?back_url=http%3A%2F%2Ftest.host%2F'
    end
  end

  def test_user_session_with_expired_atime_should_be_reset_if_timeout_enabled
    with_settings :session_timeout => '60' do
      get :index, {}, {:user_id => 2, :atime => 4.hours.ago.utc.to_i}
      assert_redirected_to 'http://test.host/login?back_url=http%3A%2F%2Ftest.host%2F'
    end
  end

  def test_user_session_with_valid_atime_should_not_be_reset_if_timeout_enabled
    with_settings :session_timeout => '60' do
      get :index, {}, {:user_id => 2, :atime => 10.minutes.ago.utc.to_i}
      assert_response :success
    end
  end

  def test_expired_user_session_should_be_restarted_if_autologin
    with_settings :session_lifetime => '720', :session_timeout => '60', :autologin => 7 do
      token = Token.create!(:user_id => 2, :action => 'autologin', :created_on => 1.day.ago)
      @request.cookies['autologin'] = token.value
      created = 2.hours.ago.utc.to_i

      get :index, {}, {:user_id => 2, :ctime => created, :atime => created}
      assert_equal 2, session[:user_id]
      assert_response :success
      assert_not_equal created, session[:ctime]
      assert session[:ctime] >= created
    end
  end

  def test_expired_user_session_should_set_locale
    set_language_if_valid 'it'
    user = User.find(2)
    user.language = 'fr'
    user.save!

    with_settings :session_timeout => '60' do
      get :index, {}, {:user_id => user.id, :atime => 4.hours.ago.utc.to_i}
      assert_redirected_to 'http://test.host/login?back_url=http%3A%2F%2Ftest.host%2F'
      assert_include "Veuillez vous reconnecter", flash[:error]
      assert_equal :fr, current_language
    end
  end

  def test_anonymous_session_should_not_be_reset
    with_settings :session_lifetime => '720', :session_timeout => '60' do
      get :index
      assert_response :success
    end
  end
end
