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

require File.expand_path('../../test_helper', __FILE__)

class AccountTest < Redmine::IntegrationTest
  fixtures :users, :email_addresses, :roles

  def test_login
    get "/my/page"
    assert_redirected_to "/login?back_url=http%3A%2F%2Fwww.example.com%2Fmy%2Fpage"
    log_user('jsmith', 'jsmith')

    get "/my/account"
    assert_response :success
  end

  def test_login_should_set_session_token
    assert_difference 'Token.count' do
      log_user('jsmith', 'jsmith')

      assert_equal 2, session[:user_id]
      assert_not_nil session[:tk]
    end
  end

  def test_autologin
    user = User.find(1)
    Token.delete_all

    with_settings :autologin => '7' do
      assert_difference 'Token.count', 2 do
        # User logs in with 'autologin' checked
        post(
          '/login',
          :params => {
            :username => user.login,
            :password => 'admin',
            :autologin => 1
          }
        )
        assert_redirected_to '/my/page'
      end
      token = Token.where(:action => 'autologin').order(:id => :desc).first
      assert_not_nil token
      assert_equal user, token.user
      assert_equal 'autologin', token.action
      assert_equal user.id, session[:user_id]
      assert_equal token.value, cookies['autologin']

      # Session is cleared
      reset!
      User.current = nil
      # Clears user's last login timestamp
      user.update_attribute :last_login_on, nil
      assert_nil user.reload.last_login_on

      # User comes back with user's autologin cookie
      cookies[:autologin] = token.value
      get '/my/page'
      assert_response :success
      assert_equal user.id, session[:user_id]
      assert_not_nil user.reload.last_login_on
    end
  end

  def test_autologin_should_use_autologin_cookie_name
    Token.delete_all
    Redmine::Configuration.stubs(:[]).with('autologin_cookie_name').returns('custom_autologin')
    Redmine::Configuration.stubs(:[]).with('autologin_cookie_path').returns('/')
    Redmine::Configuration.stubs(:[]).with('autologin_cookie_secure').returns(false)
    Redmine::Configuration.stubs(:[]).with('sudo_mode_timeout').returns(15)

    with_settings :autologin => '7' do
      assert_difference 'Token.count', 2 do
        post(
          '/login',
          :params => {
            :username => 'admin',
            :password => 'admin',
            :autologin => 1
          }
        )
        assert_response 302
      end
      assert cookies['custom_autologin'].present?
      token = cookies['custom_autologin']

      # Session is cleared
      reset!
      cookies['custom_autologin'] = token
      get '/my/page'
      assert_response :success

      assert_difference 'Token.count', -2 do
        post '/logout'
      end
      assert cookies['custom_autologin'].blank?
    end
  end

  def test_lost_password
    Token.delete_all

    get "/account/lost_password"
    assert_response :success
    assert_select 'input[name=mail]'

    post("/account/lost_password", :params => {:mail => 'jSmith@somenet.foo'})
    assert_redirected_to "/login"

    token = Token.first
    assert_equal 'recovery', token.action
    assert_equal 'jsmith@somenet.foo', token.user.mail
    assert !token.expired?

    get("/account/lost_password", :params => {:token => token.value})
    assert_redirected_to '/account/lost_password'

    follow_redirect!
    assert_response :success
    assert_select 'input[type=hidden][name=token][value=?]', token.value
    assert_select 'input[name=new_password]'
    assert_select 'input[name=new_password_confirmation]'

    post(
      "/account/lost_password",
      :params => {
        :token => token.value, :new_password => 'newpass123',
        :new_password_confirmation => 'newpass123'
      }
    )
    assert_redirected_to "/login"
    assert_equal 'Password was successfully updated.', flash[:notice]

    log_user('jsmith', 'newpass123')
    assert_equal false, Token.exists?(token.id), "Password recovery token was not deleted"
  end

  def test_lost_password_expired_token
    Token.delete_all

    get "/account/lost_password"
    assert_response :success
    assert_select 'input[name=mail]'

    post("/account/lost_password", :params => {:mail => 'jSmith@somenet.foo'})
    assert_redirected_to "/login"

    token = Token.first
    assert_equal 'recovery', token.action
    assert_equal 'jsmith@somenet.foo', token.user.mail
    refute token.expired?

    get("/account/lost_password", :params => {:token => token.value})
    assert_redirected_to '/account/lost_password'

    follow_redirect!
    assert_response :success

    # suppose the user forgets to continue the process and the token expires.
    token.update_column :created_on, 1.week.ago
    assert token.expired?

    assert_select 'input[type=hidden][name=token][value=?]', token.value
    assert_select 'input[name=new_password]'
    assert_select 'input[name=new_password_confirmation]'

    post(
      "/account/lost_password",
      :params => {
        :token => token.value, :new_password => 'newpass123',
        :new_password_confirmation => 'newpass123'
      }
    )
    assert_redirected_to "/account/lost_password"
    assert_equal 'This password recovery link has expired, please try again.', flash[:error]
    follow_redirect!
    assert_response :success

    post("/account/lost_password", :params => {:mail => 'jSmith@somenet.foo'})
    assert_redirected_to "/login"

    # should have a new token now
    token = Token.last
    assert_equal 'recovery', token.action
    assert_equal 'jsmith@somenet.foo', token.user.mail
    refute token.expired?
  end

  def test_user_with_must_change_passwd_should_be_forced_to_change_its_password
    User.find_by_login('jsmith').update_attribute :must_change_passwd, true

    post('/login', :params => {:username => 'jsmith', :password => 'jsmith'})
    assert_redirected_to '/my/page'
    follow_redirect!
    assert_redirected_to '/my/password'

    get '/issues'
    assert_redirected_to '/my/password'
  end

  def test_flash_message_should_use_user_language_when_redirecting_user_for_password_change
    user = User.find_by_login('jsmith')
    user.must_change_passwd = true
    user.language = 'it'
    user.save!

    post('/login', :params => {:username => 'jsmith', :password => 'jsmith'})
    assert_redirected_to '/my/page'
    follow_redirect!
    assert_redirected_to '/my/password'
    follow_redirect!

    assert_select 'div.error', :text => /richiesto che sia cambiata/
  end

  def test_user_with_must_change_passwd_should_be_able_to_change_its_password
    User.find_by_login('jsmith').update_attribute :must_change_passwd, true

    post('/login', :params => {:username => 'jsmith', :password => 'jsmith'})
    assert_redirected_to '/my/page'
    follow_redirect!
    assert_redirected_to '/my/password'
    follow_redirect!
    assert_response :success
    post(
      '/my/password',
      :params => {
        :password => 'jsmith',
        :new_password => 'newpassword',
        :new_password_confirmation => 'newpassword'
      }
    )
    assert_redirected_to '/my/account'
    follow_redirect!
    assert_response :success

    assert_equal false, User.find_by_login('jsmith').must_change_passwd?
  end

  def test_user_with_expired_password_should_be_forced_to_change_its_password
    User.find_by_login('jsmith').update_attribute :passwd_changed_on, 14.days.ago

    with_settings :password_max_age => 7 do
      post('/login', :params => {:username => 'jsmith', :password => 'jsmith'})
      assert_redirected_to '/my/page'
      follow_redirect!
      assert_redirected_to '/my/password'

      get '/issues'
      assert_redirected_to '/my/password'
    end
  end

  def test_user_with_expired_password_should_be_able_to_change_its_password
    User.find_by_login('jsmith').update_attribute :passwd_changed_on, 14.days.ago

    with_settings :password_max_age => 7 do
      post('/login', :params => {:username => 'jsmith', :password => 'jsmith'})
      assert_redirected_to '/my/page'
      follow_redirect!
      assert_redirected_to '/my/password'
      follow_redirect!
      assert_response :success
      post(
        '/my/password',
        :params => {
          :password => 'jsmith',
          :new_password => 'newpassword',
          :new_password_confirmation => 'newpassword'
        }
      )
      assert_redirected_to '/my/account'
      follow_redirect!
      assert_response :success

      assert_equal false, User.find_by_login('jsmith').must_change_passwd?
    end

  end

  def test_register_with_automatic_activation
    Setting.self_registration = '3'

    get '/account/register'
    assert_response :success

    post(
      '/account/register',
      :params => {
        :user => {
          :login => "newuser", :language => "en",
          :firstname => "New", :lastname => "User", :mail => "newuser@foo.bar",
          :password => "newpass123", :password_confirmation => "newpass123"
        }
      }
    )
    assert_redirected_to '/my/account'
    follow_redirect!
    assert_response :success

    user = User.find_by_login('newuser')
    assert_not_nil user
    assert user.active?
    assert_not_nil user.last_login_on
  end

  def test_register_with_manual_activation
    Setting.self_registration = '2'

    post(
      '/account/register',
      :params => {
        :user => {
          :login => "newuser", :language => "en",
          :firstname => "New", :lastname => "User", :mail => "newuser@foo.bar",
          :password => "newpass123", :password_confirmation => "newpass123"
        }
      }
    )
    assert_redirected_to '/login'
    assert !User.find_by_login('newuser').active?
  end

  def test_register_with_email_activation
    Setting.self_registration = '1'
    Token.delete_all

    post(
      '/account/register',
      :params => {
        :user => {
          :login => "newuser", :language => "en",
          :firstname => "New", :lastname => "User", :mail => "newuser@foo.bar",
          :password => "newpass123", :password_confirmation => "newpass123"
        }
      }
    )
    assert_redirected_to '/login'
    assert !User.find_by_login('newuser').active?

    token = Token.first
    assert_equal 'register', token.action
    assert_equal 'newuser@foo.bar', token.user.mail
    assert !token.expired?

    get('/account/activate', :params => {:token => token.value})
    assert_redirected_to '/login'
    log_user('newuser', 'newpass123')
  end

  def test_onthefly_registration
    # disable registration
    Setting.self_registration = '0'
    AuthSource.expects(:authenticate).returns(
      {:login => 'foo', :firstname => 'Foo', :lastname => 'Smith',
       :mail => 'foo@bar.com', :auth_source_id => 66}
    )
    post('/login', :params => {:username => 'foo', :password => 'bar'})
    assert_redirected_to '/my/page'

    user = User.find_by_login('foo')
    assert user.is_a?(User)
    assert_equal 66, user.auth_source_id
    assert user.hashed_password.blank?
  end

  def test_onthefly_registration_with_invalid_attributes
    # disable registration
    Setting.self_registration = '0'
    AuthSource.expects(:authenticate).returns(
      {:login => 'foo', :lastname => 'Smith', :auth_source_id => 66}
    )
    post('/login', :params => {:username => 'foo', :password => 'bar'})
    assert_response :success
    assert_select 'input[name=?][value=""]', 'user[firstname]'
    assert_select 'input[name=?][value=Smith]', 'user[lastname]'
    assert_select 'input[name=?]', 'user[login]', 0
    assert_select 'input[name=?]', 'user[password]', 0

    post(
      '/account/register',
      :params => {
        :user => {
          :firstname => 'Foo', :lastname => 'Smith', :mail => 'foo@bar.com'
        }
      }
    )
    assert_redirected_to '/my/account'

    user = User.find_by_login('foo')
    assert user.is_a?(User)
    assert_equal 66, user.auth_source_id
    assert user.hashed_password.blank?
  end

  def test_registered_user_should_be_able_to_get_a_new_activation_email
    Token.delete_all

    with_settings :self_registration => '1', :default_language => 'en' do
      # register a new account
      assert_difference 'User.count' do
        assert_difference 'Token.count' do
          post(
            '/account/register',
            :params => {
              :user => {
                :login => "newuser", :language => "en",
                :firstname => "New", :lastname => "User", :mail => "newuser@foo.bar",
                :password => "newpass123", :password_confirmation => "newpass123"
              }
            }
          )
        end
      end
      user = User.order('id desc').first
      assert_equal User::STATUS_REGISTERED, user.status
      reset!

      # try to use "lost password"
      assert_no_difference 'ActionMailer::Base.deliveries.size' do
        post(
          '/account/lost_password',
          :params => {
            :mail => 'newuser@foo.bar'
          }
        )
      end
      assert_redirected_to '/account/lost_password'
      follow_redirect!
      assert_response :success
      assert_select 'div.flash', :text => /new activation email/
      assert_select 'div.flash a[href="/account/activation_email"]'

      # request a new action activation email
      assert_difference 'ActionMailer::Base.deliveries.size' do
        get '/account/activation_email'
      end
      assert_redirected_to '/login'
      token = Token.order('id desc').first
      activation_path = "/account/activate?token=#{token.value}"
      assert_include activation_path, mail_body(ActionMailer::Base.deliveries.last)

      # activate the account
      get activation_path
      assert_redirected_to '/login'

      post('/login', :params => {:username => 'newuser', :password => 'newpass123'})
      assert_redirected_to '/my/page'
    end
  end
end
