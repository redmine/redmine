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

class WatchersHelperTest < Redmine::HelperTest
  include WatchersHelper
  include AvatarsHelper
  include ERB::Util

  test '#watcher_link with a non-watched object' do
    expected = link_to(
      sprite_icon("fav", "Watch"),
      "/watchers/watch?object_id=1&object_type=issue",
      :remote => true, :method => 'post', :class => "issue-1-watcher icon icon-fav-off"
    )
    assert_equal expected, watcher_link(Issue.find(1), User.find(1))
  end

  test '#watcher_link with a single object array' do
    expected = link_to(
      sprite_icon("fav", "Watch"),
      "/watchers/watch?object_id=1&object_type=issue",
      :remote => true, :method => 'post', :class => "issue-1-watcher icon icon-fav-off"
    )
    assert_equal expected, watcher_link([Issue.find(1)], User.find(1))
  end

  test '#watcher_link with a multiple objects array' do
    expected = link_to(
      sprite_icon("fav", "Watch"),
      "/watchers/watch?object_id%5B%5D=1&object_id%5B%5D=3&object_type=issue",
      :remote => true, :method => 'post', :class => "issue-bulk-watcher icon icon-fav-off"
    )
    assert_equal expected, watcher_link([Issue.find(1), Issue.find(3)], User.find(1))
  end

  def test_watcher_link_with_nil_should_return_empty_string
    assert_equal '', watcher_link(nil, User.find(1))
  end

  test '#watcher_link with a watched object' do
    Watcher.create!(:watchable => Issue.find(1), :user => User.find(1))

    expected = link_to(
      sprite_icon("fav", "Unwatch"),
      "/watchers/watch?object_id=1&object_type=issue",
      :remote => true, :method => 'delete', :class => "issue-1-watcher icon icon-fav"
    )
    assert_equal expected, watcher_link(Issue.find(1), User.find(1))
  end

  def test_watchers_list_should_be_sorted_by_user_name
    issue = Issue.find(1)
    [1, 2, 3].shuffle.each do |user_id|
      Watcher.create!(:watchable => issue, :user => User.find(user_id))
    end

    with_settings user_format: 'firstname_lastname' do
      result1 = watchers_list(issue)
      assert_select_in result1, 'ul.watchers' do
        assert_select 'li', 3
        assert_select 'li:nth-of-type(1)>a[href=?]', '/users/3', text: 'Dave Lopper'
        assert_select 'li:nth-of-type(2)>a[href=?]', '/users/2', text: 'John Smith'
        assert_select 'li:nth-of-type(3)>a[href=?]', '/users/1', text: 'Redmine Admin'
      end
    end

    with_settings user_format: 'lastname_firstname' do
      result2 = watchers_list(issue)
      assert_select_in result2, 'ul.watchers' do
        assert_select 'li', 3
        assert_select 'li:nth-of-type(1)>a[href=?]', '/users/1', text: 'Admin Redmine'
        assert_select 'li:nth-of-type(2)>a[href=?]', '/users/3', text: 'Lopper Dave'
        assert_select 'li:nth-of-type(3)>a[href=?]', '/users/2', text: 'Smith John'
      end
    end
  end
end
