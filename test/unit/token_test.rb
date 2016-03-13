# Redmine - project management software
# Copyright (C) 2006-2016  Jean-Philippe Lang
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

class TokenTest < ActiveSupport::TestCase
  fixtures :tokens

  def test_create
    token = Token.new
    token.save
    assert_equal 40, token.value.length
    assert !token.expired?
  end

  def test_create_should_remove_existing_tokens
    user = User.find(1)
    t1 = Token.create(:user => user, :action => 'autologin')
    t2 = Token.create(:user => user, :action => 'autologin')
    assert_not_equal t1.value, t2.value
    assert !Token.exists?(t1.id)
    assert  Token.exists?(t2.id)
  end

  def test_create_session_token_should_keep_last_10_tokens
    Token.delete_all
    user = User.find(1)

    assert_difference 'Token.count', 10 do
      10.times { Token.create!(:user => user, :action => 'session') }
    end

    assert_no_difference 'Token.count' do
      Token.create!(:user => user, :action => 'session')
    end
  end

  def test_destroy_expired_should_not_destroy_feeds_and_api_tokens
    Token.delete_all

    Token.create!(:user_id => 1, :action => 'api', :created_on => 7.days.ago)
    Token.create!(:user_id => 1, :action => 'feeds', :created_on => 7.days.ago)

    assert_no_difference 'Token.count' do
      assert_equal 0, Token.destroy_expired
    end
  end

  def test_destroy_expired_should_destroy_expired_tokens
    Token.delete_all

    Token.create!(:user_id => 1, :action => 'autologin', :created_on => 7.days.ago)
    Token.create!(:user_id => 2, :action => 'autologin', :created_on => 3.days.ago)
    Token.create!(:user_id => 3, :action => 'autologin', :created_on => 1.hour.ago)

    assert_difference 'Token.count', -2 do
      assert_equal 2, Token.destroy_expired
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
