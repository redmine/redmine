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

class SessionsControllerTest < ActionController::TestCase
  include Redmine::I18n
  tests WelcomeController

  fixtures :users, :email_addresses

  def setup
    Rails.application.config.redmine_verify_sessions = true
  end

  def teardown
    Rails.application.config.redmine_verify_sessions = false
  end

  def test_session_token_should_be_updated
    token = Token.create!(:user_id => 2, :action => 'session', :created_on => 10.hours.ago, :updated_on => 10.hours.ago)
    created = token.reload.created_on

    get :index, {}, {:user_id => 2, :tk => token.value}
    assert_response :success
    token.reload
    assert_equal created.to_i, token.created_on.to_i
    assert_not_equal created.to_i, token.updated_on.to_i
    assert token.updated_on > created
  end

  def test_user_session_should_not_be_reset_if_lifetime_and_timeout_disabled
    created = 2.years.ago
    token = Token.create!(:user_id => 2, :action => 'session', :created_on => created, :updated_on => created)

    with_settings :session_lifetime => '0', :session_timeout => '0' do
      get :index, {}, {:user_id => 2, :tk => token.value}
      assert_response :success
    end
  end

  def test_user_session_without_token_should_be_reset
    get :index, {}, {:user_id => 2}
    assert_redirected_to 'http://test.host/login?back_url=http%3A%2F%2Ftest.host%2F'
  end

  def test_expired_user_session_should_be_reset_if_lifetime_enabled
    created = 2.days.ago
    token = Token.create!(:user_id => 2, :action => 'session', :created_on => created, :updated_on => created)

    with_settings :session_timeout => '720' do
      get :index, {}, {:user_id => 2, :tk => token.value}
      assert_redirected_to 'http://test.host/login?back_url=http%3A%2F%2Ftest.host%2F'
    end
  end

  def test_valid_user_session_should_not_be_reset_if_lifetime_enabled
    created = 3.hours.ago
    token = Token.create!(:user_id => 2, :action => 'session', :created_on => created, :updated_on => created)

    with_settings :session_timeout => '720' do
      get :index, {}, {:user_id => 2, :tk => token.value}
      assert_response :success
    end
  end

  def test_expired_user_session_should_be_reset_if_timeout_enabled
    created = 4.hours.ago
    token = Token.create!(:user_id => 2, :action => 'session', :created_on => created, :updated_on => created)

    with_settings :session_timeout => '60' do
      get :index, {}, {:user_id => 2, :tk => token.value}
      assert_redirected_to 'http://test.host/login?back_url=http%3A%2F%2Ftest.host%2F'
    end
  end

  def test_valid_user_session_should_not_be_reset_if_timeout_enabled
    created = 10.minutes.ago
    token = Token.create!(:user_id => 2, :action => 'session', :created_on => created, :updated_on => created)

    with_settings :session_timeout => '60' do
      get :index, {}, {:user_id => 2, :tk => token.value}
      assert_response :success
    end
  end

  def test_expired_user_session_should_be_restarted_if_autologin
    created = 2.hours.ago
    token = Token.create!(:user_id => 2, :action => 'session', :created_on => created, :updated_on => created)

    with_settings :session_lifetime => '720', :session_timeout => '60', :autologin => 7 do
      autologin_token = Token.create!(:user_id => 2, :action => 'autologin', :created_on => 1.day.ago)
      @request.cookies['autologin'] = autologin_token.value

      get :index, {}, {:user_id => 2, :tk => token.value}
      assert_equal 2, session[:user_id]
      assert_response :success
      assert_not_equal token.value, session[:tk]
    end
  end

  def test_expired_user_session_should_set_locale
    set_language_if_valid 'it'
    user = User.find(2)
    user.language = 'fr'
    user.save!
    created = 4.hours.ago
    token = Token.create!(:user_id => 2, :action => 'session', :created_on => created, :updated_on => created)

    with_settings :session_timeout => '60' do
      get :index, {}, {:user_id => user.id, :tk => token.value}
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
