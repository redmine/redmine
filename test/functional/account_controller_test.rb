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

require File.expand_path('../../test_helper', __FILE__)

class AccountControllerTest < ActionController::TestCase
  fixtures :users, :roles

  def setup
    User.current = nil
  end

  def test_get_login
    get :login
    assert_response :success
    assert_template 'login'

    assert_select 'input[name=username]'
    assert_select 'input[name=password]'
  end

  def test_get_login_while_logged_in_should_redirect_to_home
    @request.session[:user_id] = 2

    get :login
    assert_redirected_to '/'
    assert_equal 2, @request.session[:user_id]
  end

  def test_login_should_redirect_to_back_url_param
    # request.uri is "test.host" in test environment
    post :login, :username => 'jsmith', :password => 'jsmith', :back_url => 'http://test.host/issues/show/1'
    assert_redirected_to '/issues/show/1'
  end

  def test_login_should_not_redirect_to_another_host
    post :login, :username => 'jsmith', :password => 'jsmith', :back_url => 'http://test.foo/fake'
    assert_redirected_to '/my/page'
  end

  def test_login_with_wrong_password
    post :login, :username => 'admin', :password => 'bad'
    assert_response :success
    assert_template 'login'

    assert_select 'div.flash.error', :text => /Invalid user or password/
    assert_select 'input[name=username][value=admin]'
    assert_select 'input[name=password]'
    assert_select 'input[name=password][value]', 0
  end

  def test_login_with_locked_account_should_fail
    User.find(2).update_attribute :status, User::STATUS_LOCKED

    post :login, :username => 'jsmith', :password => 'jsmith'
    assert_redirected_to '/login'
    assert_include 'locked', flash[:error]
    assert_nil @request.session[:user_id]
  end

  def test_login_as_registered_user_with_manual_activation_should_inform_user
    User.find(2).update_attribute :status, User::STATUS_REGISTERED

    with_settings :self_registration => '2', :default_language => 'en' do
      post :login, :username => 'jsmith', :password => 'jsmith'
      assert_redirected_to '/login'
      assert_include 'pending administrator approval', flash[:error]
    end
  end

  def test_login_as_registered_user_with_email_activation_should_propose_new_activation_email
    User.find(2).update_attribute :status, User::STATUS_REGISTERED

    with_settings :self_registration => '1', :default_language => 'en' do
      post :login, :username => 'jsmith', :password => 'jsmith'
      assert_redirected_to '/login'
      assert_equal 2, @request.session[:registered_user_id]
      assert_include 'new activation email', flash[:error]
    end
  end

  def test_login_should_rescue_auth_source_exception
    source = AuthSource.create!(:name => 'Test')
    User.find(2).update_attribute :auth_source_id, source.id
    AuthSource.any_instance.stubs(:authenticate).raises(AuthSourceException.new("Something wrong"))

    post :login, :username => 'jsmith', :password => 'jsmith'
    assert_response 500
    assert_error_tag :content => /Something wrong/
  end

  def test_login_should_reset_session
    @controller.expects(:reset_session).once

    post :login, :username => 'jsmith', :password => 'jsmith'
    assert_response 302
  end

  def test_get_logout_should_not_logout
    @request.session[:user_id] = 2
    get :logout
    assert_response :success
    assert_template 'logout'

    assert_equal 2, @request.session[:user_id]
  end

  def test_logout
    @request.session[:user_id] = 2
    post :logout
    assert_redirected_to '/'
    assert_nil @request.session[:user_id]
  end

  def test_logout_should_reset_session
    @controller.expects(:reset_session).once

    @request.session[:user_id] = 2
    post :logout
    assert_response 302
  end

  def test_get_register_with_registration_on
    with_settings :self_registration => '3' do
      get :register
      assert_response :success
      assert_template 'register'
      assert_not_nil assigns(:user)

      assert_select 'input[name=?]', 'user[password]'
      assert_select 'input[name=?]', 'user[password_confirmation]'
    end
  end

  def test_get_register_should_detect_user_language
    with_settings :self_registration => '3' do
      @request.env['HTTP_ACCEPT_LANGUAGE'] = 'fr,fr-fr;q=0.8,en-us;q=0.5,en;q=0.3'
      get :register
      assert_response :success
      assert_not_nil assigns(:user)
      assert_equal 'fr', assigns(:user).language
      assert_select 'select[name=?]', 'user[language]' do
        assert_select 'option[value=fr][selected=selected]'
      end
    end
  end

  def test_get_register_with_registration_off_should_redirect
    with_settings :self_registration => '0' do
      get :register
      assert_redirected_to '/'
    end
  end

  # See integration/account_test.rb for the full test
  def test_post_register_with_registration_on
    with_settings :self_registration => '3' do
      assert_difference 'User.count' do
        post :register, :user => {
          :login => 'register',
          :password => 'secret123',
          :password_confirmation => 'secret123',
          :firstname => 'John',
          :lastname => 'Doe',
          :mail => 'register@example.com'
        }
        assert_redirected_to '/my/account'
      end
      user = User.first(:order => 'id DESC')
      assert_equal 'register', user.login
      assert_equal 'John', user.firstname
      assert_equal 'Doe', user.lastname
      assert_equal 'register@example.com', user.mail
      assert user.check_password?('secret123')
      assert user.active?
    end
  end
  
  def test_post_register_with_registration_off_should_redirect
    with_settings :self_registration => '0' do
      assert_no_difference 'User.count' do
        post :register, :user => {
          :login => 'register',
          :password => 'test',
          :password_confirmation => 'test',
          :firstname => 'John',
          :lastname => 'Doe',
          :mail => 'register@example.com'
        }
        assert_redirected_to '/'
      end
    end
  end

  def test_get_lost_password_should_display_lost_password_form
    get :lost_password
    assert_response :success
    assert_select 'input[name=mail]'
  end

  def test_lost_password_for_active_user_should_create_a_token
    Token.delete_all
    ActionMailer::Base.deliveries.clear
    assert_difference 'ActionMailer::Base.deliveries.size' do
      assert_difference 'Token.count' do
        with_settings :host_name => 'mydomain.foo', :protocol => 'http' do
          post :lost_password, :mail => 'JSmith@somenet.foo'
          assert_redirected_to '/login'
        end
      end
    end

    token = Token.order('id DESC').first
    assert_equal User.find(2), token.user
    assert_equal 'recovery', token.action

    assert_select_email do
      assert_select "a[href=?]", "http://mydomain.foo/account/lost_password?token=#{token.value}"
    end
  end

  def test_lost_password_for_unknown_user_should_fail
    Token.delete_all
    assert_no_difference 'Token.count' do
      post :lost_password, :mail => 'invalid@somenet.foo'
      assert_response :success
    end
  end

  def test_lost_password_for_non_active_user_should_fail
    Token.delete_all
    assert User.find(2).lock!

    assert_no_difference 'Token.count' do
      post :lost_password, :mail => 'JSmith@somenet.foo'
      assert_redirected_to '/account/lost_password'
    end
  end

  def test_get_lost_password_with_token_should_display_the_password_recovery_form
    user = User.find(2)
    token = Token.create!(:action => 'recovery', :user => user)

    get :lost_password, :token => token.value
    assert_response :success
    assert_template 'password_recovery'

    assert_select 'input[type=hidden][name=token][value=?]', token.value
  end

  def test_get_lost_password_with_invalid_token_should_redirect
    get :lost_password, :token => "abcdef"
    assert_redirected_to '/'
  end

  def test_post_lost_password_with_token_should_change_the_user_password
    user = User.find(2)
    token = Token.create!(:action => 'recovery', :user => user)

    post :lost_password, :token => token.value, :new_password => 'newpass123', :new_password_confirmation => 'newpass123'
    assert_redirected_to '/login'
    user.reload
    assert user.check_password?('newpass123')
    assert_nil Token.find_by_id(token.id), "Token was not deleted"
  end

  def test_post_lost_password_with_token_for_non_active_user_should_fail
    user = User.find(2)
    token = Token.create!(:action => 'recovery', :user => user)
    user.lock!

    post :lost_password, :token => token.value, :new_password => 'newpass123', :new_password_confirmation => 'newpass123'
    assert_redirected_to '/'
    assert ! user.check_password?('newpass123')
  end

  def test_post_lost_password_with_token_and_password_confirmation_failure_should_redisplay_the_form
    user = User.find(2)
    token = Token.create!(:action => 'recovery', :user => user)

    post :lost_password, :token => token.value, :new_password => 'newpass', :new_password_confirmation => 'wrongpass'
    assert_response :success
    assert_template 'password_recovery'
    assert_not_nil Token.find_by_id(token.id), "Token was deleted"

    assert_select 'input[type=hidden][name=token][value=?]', token.value
  end

  def test_post_lost_password_with_invalid_token_should_redirect
    post :lost_password, :token => "abcdef", :new_password => 'newpass', :new_password_confirmation => 'newpass'
    assert_redirected_to '/'
  end

  def test_activation_email_should_send_an_activation_email
    User.find(2).update_attribute :status, User::STATUS_REGISTERED
    @request.session[:registered_user_id] = 2

    with_settings :self_registration => '1' do
      assert_difference 'ActionMailer::Base.deliveries.size' do
        get :activation_email
        assert_redirected_to '/login'
      end
    end
  end
end
