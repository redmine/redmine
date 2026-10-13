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

require_relative '../test_helper'

class SessionsTest < Redmine::IntegrationTest
  def setup
    Rails.application.config.redmine_verify_sessions = true
  end

  def teardown
    Rails.application.config.redmine_verify_sessions = false
  end

  def test_change_password_kills_sessions
    log_user('jsmith', 'jsmith')

    jsmith = User.find(2)
    jsmith.password = "somenewpassword"
    jsmith.save!

    get '/my/account'
    assert_response :found
    assert flash[:error].include?('Your session has expired')
  end

  def test_lock_user_kills_sessions
    log_user('jsmith', 'jsmith')

    jsmith = User.find(2)
    assert jsmith.lock!
    assert jsmith.activate!

    get '/my/account'
    assert_response :found
    assert flash[:error].include?('Your session has expired')
  end

  def test_update_user_does_not_kill_sessions
    log_user('jsmith', 'jsmith')

    jsmith = User.find(2)
    jsmith.firstname = 'Robert'
    jsmith.save!

    get '/my/account'
    assert_response :ok
  end

  def test_change_password_kills_all_sessions_and_generates_a_new_token_for_current_session
    other_session_token = Token.create!(:user_id => 2, :action => 'session')
    log_user('jsmith', 'jsmith')
    assert_not_nil token = session[:tk]

    get '/my/password'
    assert_response :ok
    post(
      '/my/password',
      :params => {
        :password => 'jsmith',
        :new_password => 'secret123',
        :new_password_confirmation => 'secret123'
      }
    )
    assert_response :found
    assert_not_equal token, session[:tk]
    assert_nil Token.find_by(:user_id => 2, :action => 'session', :value => token)
    assert_nil Token.find_by_id(other_session_token.id)

    get '/my/account'
    assert_response :ok
  end

  def test_change_mail_kills_sessions
    log_user('jsmith', 'jsmith')

    jsmith = User.find(2)
    jsmith.mail = 'anotheraddress@somenet.foo'
    jsmith.save!

    get '/my/account'
    assert_response :found
    assert_includes flash[:error], 'Your session has expired'
  end

  def test_change_mail_kills_all_sessions_and_generates_a_new_token_for_current_session
    other_session_token = Token.create!(:user_id => 2, :action => 'session')
    log_user('jsmith', 'jsmith')
    assert_not_nil token = session[:tk]

    put '/my/account', :params => {:user => {:mail => 'anotheraddress@somenet.foo'}}
    assert_response :found
    assert_not_equal token, session[:tk]
    assert_nil Token.find_by(:user_id => 2, :action => 'session', :value => token)
    assert_nil Token.find_by_id(other_session_token.id)

    get '/my/account'
    assert_response :ok
  end

  def test_destroy_email_address_kills_all_sessions_and_generates_a_new_token_for_current_session
    email = EmailAddress.create!(:user_id => 2, :address => 'another@somenet.foo')
    other_session_token = Token.create!(:user_id => 2, :action => 'session')

    log_user('jsmith', 'jsmith')
    assert_not_nil token = session[:tk]

    delete "/users/2/email_addresses/#{email.id}"
    assert_response :found
    assert_not_equal token, session[:tk]
    assert_nil Token.find_by(:user_id => 2, :action => 'session', :value => token)
    assert_nil Token.find_by_id(other_session_token.id)

    get '/my/account'
    assert_response :ok
  end

  def test_admin_destroying_other_users_email_address_should_not_touch_admin_session
    email = EmailAddress.create!(:user_id => 2, :address => 'another@somenet.foo')
    jsmith_session_token = Token.create!(:user_id => 2, :action => 'session')

    log_user('admin', 'admin')
    assert_not_nil token = session[:tk]

    delete "/users/2/email_addresses/#{email.id}"
    assert_response :found
    assert_equal token, session[:tk]
    assert_nil Token.find_by_id(jsmith_session_token.id)

    get '/my/account'
    assert_response :ok
  end

  def test_admin_changing_own_mail_kills_all_sessions_and_generates_a_new_token_for_current_session
    other_session_token = Token.create!(:user_id => 1, :action => 'session')
    log_user('admin', 'admin')
    assert_not_nil token = session[:tk]

    put '/users/1', :params => {:user => {:mail => 'newadmin@somenet.foo'}}
    assert_response :found
    assert_not_equal token, session[:tk]
    assert_nil Token.find_by(:user_id => 1, :action => 'session', :value => token)
    assert_nil Token.find_by_id(other_session_token.id)

    get '/my/account'
    assert_response :ok
  end

  def test_admin_changing_other_users_mail_should_kill_their_sessions_and_keep_admin_session
    jsmith_session_token = Token.create!(:user_id => 2, :action => 'session')

    log_user('admin', 'admin')
    assert_not_nil token = session[:tk]

    put '/users/2', :params => {:user => {:mail => 'anotheraddress@somenet.foo'}}
    assert_response :found
    assert_equal token, session[:tk]
    assert_nil Token.find_by_id(jsmith_session_token.id)

    get '/my/account'
    assert_response :ok
  end

  def test_simultaneous_sessions_should_be_valid
    first = open_session do |session|
      session.post "/login", :params => {:username => 'jsmith', :password => 'jsmith'}
    end
    other = open_session do |session|
      session.post "/login", :params => {:username => 'jsmith', :password => 'jsmith'}
    end

    first.get '/my/account'
    assert_equal 200, first.response.response_code
    first.post '/logout'

    other.get '/my/account'
    assert_equal 200, other.response.response_code
  end

  def test_api_request_should_not_change_session
    jsmith = User.find(2)
    jsmith.must_change_passwd = true
    jsmith.save

    log_user('jsmith', 'jsmith')
    assert_not_nil session[:pwd]

    follow_redirect!
    assert_redirected_to '/my/password'

    get '/issues.json'
    assert_response :ok
    assert_nil session[:pwd]

    get '/issues'
    assert_not_nil session[:pwd]
    assert_redirected_to '/my/password'
  end
end
