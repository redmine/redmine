# encoding: utf-8
#
# Redmine - project management software
# Copyright (C) 2006-2017  Jean-Philippe Lang
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

class SettingTest < ActiveSupport::TestCase

  def teardown
    Setting.delete_all
    Setting.clear_cache
  end

  def test_read_default
    Setting.delete_all
    Setting.clear_cache

    assert_equal "Redmine", Setting.app_title
    assert Setting.self_registration?
    assert !Setting.login_required?
  end

  def test_update
    Setting.app_title = "My title"
    assert_equal "My title", Setting.app_title
    # make sure db has been updated (INSERT)
    assert_equal "My title", Setting.find_by_name('app_title').value

    Setting.app_title = "My other title"
    assert_equal "My other title", Setting.app_title
    # make sure db has been updated (UPDATE)
    assert_equal "My other title", Setting.find_by_name('app_title').value
  end

  def test_setting_with_int_format_should_accept_numeric_only
    with_settings :session_timeout => 30 do
      Setting.session_timeout = 'foo'
      assert_equal "30", Setting.session_timeout
      Setting.session_timeout = 40
      assert_equal "40", Setting.session_timeout
    end
  end

  def test_setting_with_invalid_name_should_be_valid
    setting = Setting.new(:name => "does_not_exist", :value => "should_not_be_allowed")
    assert !setting.save
  end

  def test_serialized_setting
    Setting.notified_events = ['issue_added', 'issue_updated', 'news_added']
    assert_equal ['issue_added', 'issue_updated', 'news_added'], Setting.notified_events
    assert_equal ['issue_added', 'issue_updated', 'news_added'], Setting.find_by_name('notified_events').value
  end

  def test_setting_should_be_reloaded_after_clear_cache
    Setting.app_title = "My title"
    assert_equal "My title", Setting.app_title

    s = Setting.find_by_name("app_title")
    s.value = 'New title'
    s.save!
    assert_equal "My title", Setting.app_title

    Setting.clear_cache
    assert_equal "New title", Setting.app_title
  end

  def test_per_page_options_array_should_be_an_empty_array_when_setting_is_blank
    with_settings :per_page_options => nil do
      assert_equal [], Setting.per_page_options_array
    end

    with_settings :per_page_options => '' do
      assert_equal [], Setting.per_page_options_array
    end
  end

  def test_per_page_options_array_should_be_an_array_of_integers
    with_settings :per_page_options => '10, 25, 50' do
      assert_equal [10, 25, 50], Setting.per_page_options_array
    end
  end

  def test_per_page_options_array_should_omit_non_numerial_values
    with_settings :per_page_options => 'a, 25, 50' do
      assert_equal [25, 50], Setting.per_page_options_array
    end
  end

  def test_per_page_options_array_should_be_sorted
    with_settings :per_page_options => '25, 10, 50' do
      assert_equal [10, 25, 50], Setting.per_page_options_array
    end
  end

  def test_setting_serialied_as_binary_should_be_loaded_as_utf8_encoded_strings
    yaml = <<-YAML
---
- keywords: !binary |
    Zml4ZXMsY2xvc2VzLNC40YHQv9GA0LDQstC70LXQvdC+LNCz0L7RgtC+0LLQ
    vizRgdC00LXQu9Cw0L3QvixmaXhlZA==

  done_ratio: "100"
  status_id: "5"
YAML

    Setting.commit_update_keywords = {}
    assert_equal 1, Setting.where(:name => 'commit_update_keywords').update_all(:value => yaml)
    Setting.clear_cache

    assert_equal 'UTF-8', Setting.commit_update_keywords.first['keywords'].encoding.name
  ensure
    Setting.where(:name => 'commit_update_keywords').delete_all
    Setting.clear_cache
  end
end
