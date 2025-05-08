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

class TokenTest < ActiveSupport::TestCase
  def setup
    User.current = nil
  end

  def test_create
    token = Token.new
    token.save
    assert_equal 40, token.value.length
    assert !token.expired?
  end

  def test_create_should_remove_existing_tokens
    user = User.find(1)
    t1 = Token.create(:user => user, :action => 'register')
    t2 = Token.create(:user => user, :action => 'register')
    assert_not_equal t1.value, t2.value
    assert !Token.exists?(t1.id)
    assert  Token.exists?(t2.id)
  end

  def test_create_session_or_autologin_token_should_keep_last_10_tokens
    Token.delete_all
    user = User.find(1)

    ["autologin", "session"].each do |action|
      assert_difference 'Token.count', 10 do
        10.times {Token.create!(:user => user, :action => action)}
      end

      assert_no_difference 'Token.count' do
        Token.create!(:user => user, :action => action)
      end
    end
  end

  def test_destroy_expired_should_not_destroy_session_feeds_and_api_tokens
    Token.delete_all

    Token.create!(:user_id => 1, :action => 'api', :created_on => 7.days.ago)
    Token.create!(:user_id => 1, :action => 'feeds', :created_on => 7.days.ago)
    Token.create!(:user_id => 1, :action => 'session', :created_on => 7.days.ago)

    assert_no_difference 'Token.count' do
      assert_equal 0, Token.destroy_expired
    end
  end

  def test_destroy_expired_should_destroy_expired_tokens
    Token.delete_all

    # Expiration of autologin tokens is determined by Setting.autologin
    Setting.autologin = "7"
    Token.create!(:user_id => 2, :action => 'autologin', :created_on => 3.weeks.ago)
    Token.create!(:user_id => 3, :action => 'autologin', :created_on => 3.days.ago)

    # Expiration of register and recovery tokens is determined by Token.validity_time
    Token.create!(:user_id => 1, :action => 'register', :created_on => 7.days.ago)
    Token.create!(:user_id => 3, :action => 'register', :created_on => 7.hours.ago)

    Token.create!(:user_id => 2, :action => 'recovery', :created_on => 3.days.ago)
    Token.create!(:user_id => 3, :action => 'recovery', :created_on => 3.hours.ago)

    # Expiration of tokens with unknown action is determined by Token.validity_time
    Token.create!(:user_id => 2, :action => 'unknown_action', :created_on => 2.days.ago)
    Token.create!(:user_id => 3, :action => 'unknown_action', :created_on => 2.hours.ago)

    assert_difference 'Token.count', -4 do
      assert_equal 4, Token.destroy_expired
    end
  end

  def test_find_active_user_should_return_user
    token = Token.create!(:user_id => 1, :action => 'api')
    assert_equal User.find(1), Token.find_active_user('api', token.value)
  end

  def test_find_active_user_should_return_nil_for_locked_user
    token = Token.create!(:user_id => 1, :action => 'api')
    User.find(1).lock!
    assert_nil Token.find_active_user('api', token.value)
  end

  def test_find_user_should_return_user
    token = Token.create!(:user_id => 1, :action => 'api')
    assert_equal User.find(1), Token.find_user('api', token.value)
  end

  def test_find_user_should_return_locked_user
    token = Token.create!(:user_id => 1, :action => 'api')
    User.find(1).lock!
    assert_equal User.find(1), Token.find_user('api', token.value)
  end

  def test_find_token_should_return_the_token
    token = Token.create!(:user_id => 1, :action => 'api')
    assert_equal token, Token.find_token('api', token.value)
  end

  def test_find_token_should_return_the_token_with_validity
    token = Token.create!(:user_id => 1, :action => 'api', :created_on => 1.hour.ago)
    assert_equal token, Token.find_token('api', token.value, 1)
  end

  def test_find_token_should_return_nil_with_wrong_action
    token = Token.create!(:user_id => 1, :action => 'feeds')
    assert_nil Token.find_token('api', token.value)
  end

  def test_find_token_should_return_nil_without_user
    token = Token.create!(:user_id => 999, :action => 'api')
    assert_nil Token.find_token('api', token.value)
  end

  def test_find_token_should_return_nil_with_validity_expired
    token = Token.create!(:user_id => 999, :action => 'api', :created_on => 2.days.ago)
    assert_nil Token.find_token('api', token.value, 1)
  end
end
