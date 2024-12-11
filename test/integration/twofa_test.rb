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

class TwofaTest < Redmine::IntegrationTest
  test "should require twofa setup when configured" do
    with_settings twofa: "2" do
      assert Setting.twofa_required?
      log_user('jsmith', 'jsmith')
      follow_redirect!
      assert_redirected_to "/my/twofa/totp/activate/confirm"
    end
  end

  test "should require twofa setup when required for administrators" do
    admin = User.find_by_login 'admin'
    user = User.find_by_login 'jsmith'

    assert_not admin.must_activate_twofa?
    assert_not user.must_activate_twofa?

    with_settings twofa: "3" do
      assert_not Setting.twofa_required?

      assert Setting.twofa_optional?
      assert Setting.twofa_required_for_administrators?
      assert admin.must_activate_twofa?
      assert_not user.must_activate_twofa?

      log_user('admin', 'admin')
      follow_redirect!
      assert_redirected_to "/my/twofa/totp/activate/confirm"
    end
  end

  test "should require twofa setup when required by group" do
    user = User.find_by_login 'jsmith'
    assert_not user.must_activate_twofa?

    group = Group.first
    group.update_column :twofa_required, true
    group.users << user
    user.reload

    with_settings twofa: "0" do
      assert_not Setting.twofa_optional?
      assert_not Setting.twofa_required?
      assert_not user.must_activate_twofa?
    end

    with_settings twofa: "1" do
      assert Setting.twofa_optional?
      assert_not Setting.twofa_required?
      assert user.must_activate_twofa?
      log_user('jsmith', 'jsmith')
      follow_redirect!
      assert_redirected_to "/my/twofa/totp/activate/confirm"
    end
  end

  test 'should require to change password first when must_change_passwd is true' do
    User.find_by(login: 'jsmith').update_attribute(:must_change_passwd, true)
    with_settings twofa: '2' do
      log_user('jsmith', 'jsmith')
      follow_redirect!
      assert_redirected_to '/my/password'
      follow_redirect!
      # Skip the before action check_twofa_activation for '/my/password'
      # to avoid redirect loop
      assert_response :success
    end
  end

  test 'should allow logout even if twofa setup is required' do
    with_settings twofa: '2' do
      log_user('jsmith', 'jsmith')
      follow_redirect!
      assert_redirected_to '/my/twofa/totp/activate/confirm'
      follow_redirect!
      post '/logout'
      assert_redirected_to '/'
      follow_redirect!
      assert_response :success
    end
  end

  test "should generate and accept backup codes" do
    log_user('jsmith', 'jsmith')
    get "/my/account"
    assert_response :success
    post "/my/twofa/totp/activate/init"
    assert_redirected_to "/my/twofa/totp/activate/confirm"
    follow_redirect!
    assert_response :success

    totp = ROTP::TOTP.new User.find_by_login('jsmith').twofa_totp_key
    post "/my/twofa/totp/activate", params: {twofa_code: totp.now}
    assert_redirected_to "/my/account"
    follow_redirect!
    assert_response :success
    assert_select '.flash', /Two-factor authentication successfully enabled/i

    post "/my/twofa/backup_codes/init"
    assert_redirected_to "/my/twofa/backup_codes/confirm"
    follow_redirect!
    assert_response :success
    assert_select 'form', /Please enter your two-factor authentication code/i

    post "/my/twofa/backup_codes/create", params: {twofa_code: "wrong"}
    assert_redirected_to "/my/twofa/backup_codes/confirm"
    follow_redirect!
    assert_response :success
    assert_select 'form', /Please enter your two-factor authentication code/i

    # prevent replay attack prevention from kicking in
    User.find_by_login('jsmith').update_column :twofa_totp_last_used_at, 2.minutes.ago.to_i

    post "/my/twofa/backup_codes/create", params: {twofa_code: totp.now}
    assert_redirected_to "/my/twofa/backup_codes"
    follow_redirect!
    assert_response :success
    assert_select ".flash", /your backup codes have been generated/i

    assert code = response.body.scan(/<code>([a-z0-9]{4} [a-z0-9]{4} [a-z0-9]{4})<\/code>/).flatten.first

    post "/logout"
    follow_redirect!
    # prevent replay attack prevention from kicking in
    User.find_by_login('jsmith').update_column :twofa_totp_last_used_at, 2.minutes.ago.to_i

    # sign in with backup code
    get "/login"
    assert_nil session[:user_id]
    assert_response :success
    post "/login", params: {
      username: 'jsmith',
      password: 'jsmith'
    }
    assert_redirected_to "/account/twofa/confirm"
    follow_redirect!

    assert_select "#login-form h3", /two-factor authentication/i
    post "/account/twofa", params: {twofa_code: code}
    assert_redirected_to "/my/page"
    follow_redirect!
    assert_response :success
  end

  test "should configure totp and require code on login" do
    with_settings twofa: "2" do
      log_user('jsmith', 'jsmith')
      follow_redirect!
      assert_redirected_to "/my/twofa/totp/activate/confirm"
      follow_redirect!

      assert key = User.find_by_login('jsmith').twofa_totp_key
      assert key.present?
      totp = ROTP::TOTP.new key

      post "/my/twofa/totp/activate", params: {twofa_code: '123456789'}
      assert_redirected_to "/my/twofa/totp/activate/confirm"
      follow_redirect!

      post "/my/twofa/totp/activate", params: {twofa_code: totp.now}
      assert_redirected_to "/my/account"

      post "/logout"
      follow_redirect!

      # prevent replay attack prevention from kicking in
      User.find_by_login('jsmith').update_column :twofa_totp_last_used_at, 2.minutes.ago.to_i

      # sign in with totp
      get "/login"
      assert_nil session[:user_id]
      assert_response :success
      post "/login", params: {
        username: 'jsmith',
        password: 'jsmith'
      }

      assert_redirected_to "/account/twofa/confirm"
      follow_redirect!

      assert_select "#login-form h3", /two-factor authentication/i
      post "/account/twofa", params: {twofa_code: 'wrong code'}
      assert_redirected_to "/account/twofa/confirm"
      follow_redirect!
      assert_select "#login-form h3", /two-factor authentication/i
      assert_select ".flash", /code is invalid/i

      post "/account/twofa", params: {twofa_code: totp.now}
      assert_redirected_to "/my/page"
      follow_redirect!
      assert_response :success
    end
  end

  def test_enable_twofa_should_destroy_tokens
    recovery_token = Token.create!(:user_id => 2, :action => 'recovery')
    autologin_token = Token.create!(:user_id => 2, :action => 'autologin')

    with_settings twofa: "2" do
      log_user('jsmith', 'jsmith')
      follow_redirect!
      assert_redirected_to "/my/twofa/totp/activate/confirm"
      follow_redirect!

      assert key = User.find_by_login('jsmith').twofa_totp_key
      assert key.present?
      totp = ROTP::TOTP.new key

      post "/my/twofa/totp/activate", params: {twofa_code: '123456789'}
      assert_redirected_to "/my/twofa/totp/activate/confirm"
      follow_redirect!

      post "/my/twofa/totp/activate", params: {twofa_code: totp.now}
      assert_redirected_to "/my/account"
    end

    assert_nil Token.find_by_id(recovery_token.id)
    assert_nil Token.find_by_id(autologin_token.id)
  end
end
