# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2019  Jean-Philippe Lang
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

class UserPreferenceTest < ActiveSupport::TestCase
  fixtures :users, :user_preferences

  def setup
    User.current = nil
  end

  def test_hide_mail_should_default_to_true
    preference = UserPreference.new
    assert_equal true, preference.hide_mail
  end

  def test_hide_mail_should_default_to_false_with_setting
    with_settings :default_users_hide_mail => '0' do
      preference = UserPreference.new
      assert_equal false, preference.hide_mail
    end
  end

  def test_time_zone_should_default_to_setting
    with_settings :default_users_time_zone => 'Paris' do
      preference = UserPreference.new
      assert_equal 'Paris', preference.time_zone
    end
  end

  def test_no_self_notified_should_default_to_true
    preference = UserPreference.new
    assert_equal true, preference.no_self_notified
  end

  def test_create
    user = User.new(:firstname => "new", :lastname => "user", :mail => "newuser@somenet.foo")
    user.login = "newuser"
    user.password, user.password_confirmation = "password", "password"
    assert user.save

    assert_kind_of UserPreference, user.pref
    assert_kind_of Hash, user.pref.others
    assert user.pref.save
  end

  def test_update
    user = User.find(1)
    assert_equal true, user.pref.hide_mail
    user.pref['preftest'] = 'value'
    assert user.pref.save

    user.reload
    assert_equal 'value', user.pref['preftest']
  end

  def test_others_hash
    user = User.new(:firstname => "new", :lastname => "user", :mail => "newuser@somenet.foo")
    user.login = "newuser"
    user.password, user.password_confirmation = "password", "password"
    assert user.save
    assert_nil user.preference
    up = UserPreference.new(:user => user)
    assert_kind_of Hash, up.others
    up.others = nil
    assert_nil up.others
    assert up.save
    assert_kind_of Hash, up.others
  end

  def test_reading_value_from_nil_others_hash
    up = UserPreference.new(:user => User.new)
    up.others = nil
    assert_nil up.others
    assert_nil up[:foo]
  end

  def test_writing_value_to_nil_others_hash
    up = UserPreference.new(:user => User.new)
    up.others = nil
    assert_nil up.others
    up[:foo] = 'bar'
    assert_equal 'bar', up[:foo]
  end

  def test_removing_a_block_should_clear_its_settings
    up = User.find(2).pref
    up.my_page_layout = {'top' => ['news', 'documents']}
    up.my_page_settings = {'news' => {:foo => 'bar'}, 'documents' => {:baz => 'quz'}}
    up.save!

    up.remove_block 'news'
    up.save!
    assert_equal ['documents'], up.my_page_settings.keys
  end
end
