# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2022  Jean-Philippe Lang
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

class AccountControllerTest < Redmine::ControllerTest
  fixtures :users, :email_addresses, :roles

  def setup
    User.current = nil
  end

  def test_get_login
    get :login
    assert_response :success

    assert_select 'input[name=username]'
    assert_select 'input[name=password]'
  end

  def test_get_login_while_logged_in_should_redirect_to_back_url_if_present
    @request.session[:user_id] = 2
    @request.env["HTTP_REFERER"] = 'http://test.host/issues/show/1'
    get(
      :login,
      :params => {
        :back_url => 'http://test.host/issues/show/1'
      }
    )
    assert_redirected_to '/issues/show/1'
    assert_equal 2, @request.session[:user_id]
  end

  def test_get_login_while_logged_in_should_redirect_to_referer_without_back_url
    @request.session[:user_id] = 2
    @request.env["HTTP_REFERER"] = 'http://test.host/issues/show/1'

    get :login
    assert_redirected_to '/issues/show/1'
    assert_equal 2, @request.session[:user_id]
  end

  def test_get_login_while_logged_in_should_redirect_to_home_by_default
    @request.session[:user_id] = 2

    get :login
    assert_redirected_to '/'
    assert_equal 2, @request.session[:user_id]
  end

  def test_login_should_redirect_to_back_url_param
    # request.uri is "test.host" in test environment
    back_urls = [
      'http://test.host/issues/show/1',
      'http://test.host/',
      '/'
    ]
    back_urls.each do |back_url|
      post(
        :login,
        :params => {
          :username => 'jsmith',
          :password => 'jsmith',
          :back_url => back_url
        }
      )
      assert_redirected_to back_url
    end
  end

  def test_login_with_suburi_should_redirect_to_back_url_param
    @relative_url_root = Redmine::Utils.relative_url_root
    Redmine::Utils.relative_url_root = '/redmine'

    back_urls = [
      'http://test.host/redmine/issues/show/1',
      '/redmine'
    ]
    back_urls.each do |back_url|
      post(
        :login,
        :params => {
          :username => 'jsmith',
          :password => 'jsmith',
          :back_url => back_url
        }
      )
      assert_redirected_to back_url
    end
  ensure
    Redmine::Utils.relative_url_root = @relative_url_root
  end

  def test_login_should_not_redirect_to_another_host
    back_urls = [
      'http://test.foo/fake',
      '//test.foo/fake'
    ]
    back_urls.each do |back_url|
      post(
        :login, :params => {
          :username => 'jsmith',
          :password => 'jsmith',
          :back_url => back_url
        }
      )
      assert_redirected_to '/my/page'
    end
  end

  def test_login_with_suburi_should_not_redirect_to_another_suburi
    @relative_url_root = Redmine::Utils.relative_url_root
    Redmine::Utils.relative_url_root = '/redmine'
    back_urls = [
      'http://test.host/',
      'http://test.host/fake',
      'http://test.host/fake/issues',
      'http://test.host/redmine/../fake',
      'http://test.host/redmine/../fake/issues',
      'http://test.host/redmine/%2e%2e/fake',
      '//test.foo/fake',
      'http://test.host//fake',
      'http://test.host/\n//fake',
      '//bar@test.foo',
      '//test.foo',
      '////test.foo',
      '@test.foo',
      'fake@test.foo',
      '.test.foo'
    ]
    back_urls.each do |back_url|
      post(
        :login,
        :params => {
          :username => 'jsmith',
          :password => 'jsmith',
          :back_url => back_url
        }
      )
      assert_redirected_to '/my/page'
    end
  ensure
    Redmine::Utils.relative_url_root = @relative_url_root
  end

  def test_login_with_wrong_password
    post(
      :login,
      :params => {
        :username => 'admin',
        :password => 'bad'
      }
    )
    assert_response :success
    assert_select 'div.flash.error', :text => /Invalid user or password/
    assert_select 'input[name=username][value=admin]'
    assert_select 'input[name=password]'
    assert_select 'input[name=password][value]', 0
  end

  def test_login_with_locked_account_should_fail
    User.find(2).update_attribute :status, User::STATUS_LOCKED
    post(
      :login,
      :params => {
        :username => 'jsmith',
        :password => 'jsmith'
      }
    )
    assert_redirected_to '/login'
    assert_include 'locked', flash[:error]
    assert_nil @request.session[:user_id]
  end

  def test_login_as_registered_user_with_manual_activation_should_inform_user
    User.find(2).update_attribute :status, User::STATUS_REGISTERED
    with_settings :self_registration => '2', :default_language => 'en' do
      post(
        :login,
        :params => {
          :username => 'jsmith',
          :password => 'jsmith'
        }
      )
      assert_redirected_to '/login'
      assert_include 'pending administrator approval', flash[:error]
    end
  end

  def test_login_as_registered_user_with_email_activation_should_propose_new_activation_email
    User.find(2).update_attribute :status, User::STATUS_REGISTERED
    with_settings :self_registration => '1', :default_language => 'en' do
      post(
        :login,
        :params => {
          :username => 'jsmith',
          :password => 'jsmith'
        }
      )
      assert_redirected_to '/login'
      assert_equal 2, @request.session[:registered_user_id]
      assert_include 'new activation email', flash[:error]
    end
  end

  def test_login_should_rescue_auth_source_exception
    source = AuthSource.create!(:name => 'Test')
    User.find(2).update_attribute :auth_source_id, source.id
    AuthSource.any_instance.stubs(:authenticate).raises(AuthSourceException.new("Something wrong"))
    post(
      :login,
      :params => {
        :username => 'jsmith',
        :password => 'jsmith'
      }
    )
    assert_response 500
    assert_select_error /Something wrong/
  end

  def test_login_should_reset_session
    @controller.expects(:reset_session).once
    post(
      :login,
      :params => {
        :username => 'jsmith',
        :password => 'jsmith'
      }
    )
    assert_response 302
  end

  def test_login_should_strip_whitespaces_from_user_name
    post(
      :login,
      :params => {
        :username => ' jsmith ',
        :password => 'jsmith'
      }
    )
    assert_response 302
    assert_equal 2, @request.session[:user_id]
  end

  def test_get_logout_should_not_logout
    @request.session[:user_id] = 2
    get :logout
    assert_response :success

    assert_equal 2, @request.session[:user_id]
  end

  def test_get_logout_with_anonymous_should_redirect
    get :logout
    assert_redirected_to '/'
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

      assert_select 'input[name=?]', 'user[password]'
      assert_select 'input[name=?]', 'user[password_confirmation]'
    end
  end

  def test_get_register_should_detect_user_language
    with_settings :self_registration => '3' do
      @request.env['HTTP_ACCEPT_LANGUAGE'] = 'fr,fr-fr;q=0.8,en-us;q=0.5,en;q=0.3'
      get :register
      assert_response :success

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

  def test_get_register_should_show_hide_mail_preference
    get :register
    assert_select 'input[name=?][checked=checked]', 'pref[hide_mail]'
  end

  def test_get_register_should_show_hide_mail_preference_with_setting_turned_off
    with_settings :default_users_hide_mail => '0' do
      get :register
      assert_select 'input[name=?]:not([checked=checked])', 'pref[hide_mail]'
    end
  end

  # See integration/account_test.rb for the full test
  def test_post_register_with_registration_on
    with_settings :self_registration => '3' do
      assert_difference 'User.count' do
        post(
          :register,
          :params => {
            :user => {
              :login => 'register',
              :password => 'secret123',
              :password_confirmation => 'secret123',
              :firstname => 'John',
              :lastname => 'Doe',
              :mail => 'register@example.com'
            }
          }
        )
        assert_redirected_to '/my/account'
      end
      user = User.order('id DESC').first
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
        post(
          :register,
          :params => {
            :user => {
              :login => 'register',
              :password => 'test',
              :password_confirmation => 'test',
              :firstname => 'John',
              :lastname => 'Doe',
              :mail => 'register@example.com'
            }
          }
        )
        assert_redirected_to '/'
      end
    end
  end

  def test_post_register_should_create_user_with_hide_mail_preference
    with_settings :default_users_hide_mail => '0' do
      user = new_record(User) do
        post(
          :register,
          :params => {
            :user => {
              :login => 'register',
              :password => 'secret123',
              :password_confirmation => 'secret123',
              :firstname => 'John',
              :lastname => 'Doe',
              :mail => 'register@example.com'
            },
            :pref => {
              :hide_mail => '1'
            }
          }
        )
      end
      assert_equal true, user.pref.hide_mail
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
        post(
          :lost_password,
          :params => {
            :mail => 'JSmith@somenet.foo'
          }
        )
        assert_redirected_to '/login'
      end
    end
    token = Token.order('id DESC').first
    assert_equal User.find(2), token.user
    assert_equal 'recovery', token.action

    assert_select_email do
      assert_select "a[href=?]", "http://localhost:3000/account/lost_password?token=#{token.value}"
    end
  end

  def test_lost_password_with_whitespace_should_send_email_to_the_address
    Token.delete_all

    assert_difference 'ActionMailer::Base.deliveries.size' do
      assert_difference 'Token.count' do
        post(
          :lost_password,
          :params => {
            :mail => ' JSmith@somenet.foo  '
          }
        )
        assert_redirected_to '/login'
      end
    end
    mail = ActionMailer::Base.deliveries.last
    assert_equal ['jsmith@somenet.foo'], mail.to
  end

  def test_lost_password_using_additional_email_address_should_send_email_to_the_address
    EmailAddress.create!(:user_id => 2, :address => 'anotherAddress@foo.bar')
    Token.delete_all
    assert_difference 'ActionMailer::Base.deliveries.size' do
      assert_difference 'Token.count' do
        post(
          :lost_password,
          :params => {
            :mail => 'ANOTHERaddress@foo.bar'
          }
        )
        assert_redirected_to '/login'
      end
    end
    mail = ActionMailer::Base.deliveries.last
    assert_equal ['anotherAddress@foo.bar'], mail.to
  end

  def test_lost_password_for_unknown_user_should_fail
    Token.delete_all
    assert_no_difference 'Token.count' do
      post(
        :lost_password,
        :params => {
          :mail => 'invalid@somenet.foo'
        }
      )
      assert_response :success
    end
  end

  def test_lost_password_for_non_active_user_should_fail
    Token.delete_all
    assert User.find(2).lock!
    assert_no_difference 'Token.count' do
      post(
        :lost_password,
        :params => {
          :mail => 'JSmith@somenet.foo'
        }
      )
      assert_redirected_to '/account/lost_password'
    end
  end

  def test_lost_password_for_user_who_cannot_change_password_should_fail
    User.any_instance.stubs(:change_password_allowed?).returns(false)
    assert_no_difference 'Token.count' do
      post(
        :lost_password,
        :params => {
          :mail => 'JSmith@somenet.foo'
        }
      )
      assert_response :success
    end
  end

  def test_get_lost_password_with_token_should_redirect_with_token_in_session
    user = User.find(2)
    token = Token.create!(:action => 'recovery', :user => user)
    get(:lost_password, :params => {:token => token.value})
    assert_redirected_to '/account/lost_password'

    assert_equal token.value, request.session[:password_recovery_token]
  end

  def test_get_lost_password_with_token_in_session_should_display_the_password_recovery_form
    user = User.find(2)
    token = Token.create!(:action => 'recovery', :user => user)
    request.session[:password_recovery_token] = token.value

    get :lost_password
    assert_response :success

    assert_select 'input[type=hidden][name=token][value=?]', token.value
  end

  def test_get_lost_password_with_invalid_token_should_redirect
    get(:lost_password, :params => {:token => "abcdef"})
    assert_redirected_to '/'
  end

  def test_post_lost_password_with_token_should_change_the_user_password
    ActionMailer::Base.deliveries.clear
    user = User.find(2)
    token = Token.create!(:action => 'recovery', :user => user)
    post(
      :lost_password,
      :params => {
        :token => token.value,
        :new_password => 'newpass123',
        :new_password_confirmation => 'newpass123'
      }
    )
    assert_redirected_to '/login'
    user.reload
    assert user.check_password?('newpass123')
    assert_nil Token.find_by_id(token.id), "Token was not deleted"
    assert_not_nil ActionMailer::Base.deliveries.last
    assert_select_email do
      assert_select 'a[href^=?]', 'http://localhost:3000/my/password', :text => 'Change password'
    end
  end

  def test_post_lost_password_with_token_for_non_active_user_should_fail
    user = User.find(2)
    token = Token.create!(:action => 'recovery', :user => user)
    user.lock!
    post(
      :lost_password,
      :params => {
        :token => token.value,
        :new_password => 'newpass123',
        :new_password_confirmation => 'newpass123'
      }
    )
    assert_redirected_to '/'
    assert ! user.check_password?('newpass123')
  end

  def test_post_lost_password_with_token_and_password_confirmation_failure_should_redisplay_the_form
    user = User.find(2)
    token = Token.create!(:action => 'recovery', :user => user)
    post(
      :lost_password, :params => {
        :token => token.value,
        :new_password => 'newpass',
        :new_password_confirmation => 'wrongpass'
      }
    )
    assert_response :success
    assert_not_nil Token.find_by_id(token.id), "Token was deleted"

    assert_select 'input[type=hidden][name=token][value=?]', token.value
  end

  def test_post_lost_password_with_token_should_not_accept_same_password_if_user_must_change_password
    user = User.find(2)
    user.password = "originalpassword"
    user.must_change_passwd = true
    user.save!
    token = Token.create!(:action => 'recovery', :user => user)
    post(
      :lost_password,
      :params => {
        :token => token.value,
        :new_password => 'originalpassword',
        :new_password_confirmation => 'originalpassword'
      }
    )
    assert_response :success
    assert_not_nil Token.find_by_id(token.id), "Token was deleted"

    assert_select '.flash', :text => /The new password must be different/
    assert_select 'input[type=hidden][name=token][value=?]', token.value
  end

  def test_post_lost_password_with_token_should_reset_must_change_password
    user = User.find(2)
    user.password = "originalpassword"
    user.must_change_passwd = true
    user.save!
    token = Token.create!(:action => 'recovery', :user => user)
    post(
      :lost_password,
      :params => {
        :token => token.value,
        :new_password => 'newpassword',
        :new_password_confirmation => 'newpassword'
      }
    )
    assert_redirected_to '/login'

    assert_equal false, user.reload.must_change_passwd
  end

  def test_post_lost_password_with_invalid_token_should_redirect
    post(
      :lost_password,
      :params => {
        :token => "abcdef",
        :new_password => 'newpass',
        :new_password_confirmation => 'newpass'
      }
    )
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

  def test_activation_email_without_session_data_should_fail
    User.find(2).update_attribute :status, User::STATUS_REGISTERED

    with_settings :self_registration => '1' do
      assert_no_difference 'ActionMailer::Base.deliveries.size' do
        get :activation_email
        assert_redirected_to '/'
      end
    end
  end
end
