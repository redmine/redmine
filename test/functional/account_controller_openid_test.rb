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

class AccountControllerOpenidTest < ActionController::TestCase
  tests AccountController
  fixtures :users, :roles

  def setup
    User.current = nil
    Setting.openid = '1'
  end

  def teardown
    Setting.openid = '0'
  end

  if Object.const_defined?(:OpenID)

    def test_login_with_openid_for_existing_user
      Setting.self_registration = '3'
      existing_user = User.new(:firstname => 'Cool',
                               :lastname => 'User',
                               :mail => 'user@somedomain.com',
                               :identity_url => 'http://openid.example.com/good_user')
      existing_user.login = 'cool_user'
      assert existing_user.save!

      post :login, :openid_url => existing_user.identity_url
      assert_redirected_to '/my/page'
    end

    def test_login_with_invalid_openid_provider
      Setting.self_registration = '0'
      post :login, :openid_url => 'http;//openid.example.com/good_user'
      assert_redirected_to home_url
    end

    def test_login_with_openid_for_existing_non_active_user
      Setting.self_registration = '2'
      existing_user = User.new(:firstname => 'Cool',
                               :lastname => 'User',
                               :mail => 'user@somedomain.com',
                               :identity_url => 'http://openid.example.com/good_user',
                               :status => User::STATUS_REGISTERED)
      existing_user.login = 'cool_user'
      assert existing_user.save!

      post :login, :openid_url => existing_user.identity_url
      assert_redirected_to '/login'
    end

    def test_login_with_openid_with_new_user_created
      Setting.self_registration = '3'
      post :login, :openid_url => 'http://openid.example.com/good_user'
      assert_redirected_to '/my/account'
      user = User.find_by_login('cool_user')
      assert user
      assert_equal 'Cool', user.firstname
      assert_equal 'User', user.lastname
    end

    def test_login_with_openid_with_new_user_and_self_registration_off
      Setting.self_registration = '0'
      post :login, :openid_url => 'http://openid.example.com/good_user'
      assert_redirected_to home_url
      user = User.find_by_login('cool_user')
      assert_nil user
    end

    def test_login_with_openid_with_new_user_created_with_email_activation_should_have_a_token
      Setting.self_registration = '1'
      post :login, :openid_url => 'http://openid.example.com/good_user'
      assert_redirected_to '/login'
      user = User.find_by_login('cool_user')
      assert user

      token = Token.find_by_user_id_and_action(user.id, 'register')
      assert token
    end

    def test_login_with_openid_with_new_user_created_with_manual_activation
      Setting.self_registration = '2'
      post :login, :openid_url => 'http://openid.example.com/good_user'
      assert_redirected_to '/login'
      user = User.find_by_login('cool_user')
      assert user
      assert_equal User::STATUS_REGISTERED, user.status
    end

    def test_login_with_openid_with_new_user_with_conflict_should_register
      Setting.self_registration = '3'
      existing_user = User.new(:firstname => 'Cool', :lastname => 'User', :mail => 'user@somedomain.com')
      existing_user.login = 'cool_user'
      assert existing_user.save!

      post :login, :openid_url => 'http://openid.example.com/good_user'
      assert_response :success
      assert_template 'register'
      assert assigns(:user)
      assert_equal 'http://openid.example.com/good_user', assigns(:user)[:identity_url]
    end

    def test_login_with_openid_with_new_user_with_missing_information_should_register
      Setting.self_registration = '3'

      post :login, :openid_url => 'http://openid.example.com/good_blank_user'
      assert_response :success
      assert_template 'register'
      assert assigns(:user)
      assert_equal 'http://openid.example.com/good_blank_user', assigns(:user)[:identity_url]

      assert_select 'input[name=?]', 'user[login]'
      assert_select 'input[name=?]', 'user[password]'
      assert_select 'input[name=?]', 'user[password_confirmation]'
      assert_select 'input[name=?][value=?]', 'user[identity_url]', 'http://openid.example.com/good_blank_user'
    end

    def test_post_login_should_not_verify_token_when_using_open_id
      ActionController::Base.allow_forgery_protection = true
      AccountController.any_instance.stubs(:using_open_id?).returns(true)
      AccountController.any_instance.stubs(:authenticate_with_open_id).returns(true)
      post :login
      assert_response 200
    ensure
      ActionController::Base.allow_forgery_protection = false
    end

    def test_register_after_login_failure_should_not_require_user_to_enter_a_password
      Setting.self_registration = '3'

      assert_difference 'User.count' do
        post :register, :user => {
          :login => 'good_blank_user',
          :password => '',
          :password_confirmation => '',
          :firstname => 'Cool',
          :lastname => 'User',
          :mail => 'user@somedomain.com',
          :identity_url => 'http://openid.example.com/good_blank_user'
        }
        assert_response 302
      end

      user = User.order('id DESC').first
      assert_equal 'http://openid.example.com/good_blank_user', user.identity_url
      assert user.hashed_password.blank?, "Hashed password was #{user.hashed_password}"
    end

    def test_setting_openid_should_return_true_when_set_to_true
      assert_equal true, Setting.openid?
    end

  else
    puts "Skipping openid tests."

    def test_dummy
    end
  end
end
