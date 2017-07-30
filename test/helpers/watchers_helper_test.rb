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

class WatchersHelperTest < Redmine::HelperTest
  include WatchersHelper
  include Rails.application.routes.url_helpers

  fixtures :users, :issues

  test '#watcher_link with a non-watched object' do
    expected = link_to(
      "Watch",
      "/watchers/watch?object_id=1&object_type=issue",
      :remote => true, :method => 'post', :class => "issue-1-watcher icon icon-fav-off"
    )
    assert_equal expected, watcher_link(Issue.find(1), User.find(1))
  end

  test '#watcher_link with a single objet array' do
    expected = link_to(
      "Watch",
      "/watchers/watch?object_id=1&object_type=issue",
      :remote => true, :method => 'post', :class => "issue-1-watcher icon icon-fav-off"
    )
    assert_equal expected, watcher_link([Issue.find(1)], User.find(1))
  end

  test '#watcher_link with a multiple objets array' do
    expected = link_to(
      "Watch",
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
      "Unwatch",
      "/watchers/watch?object_id=1&object_type=issue",
      :remote => true, :method => 'delete', :class => "issue-1-watcher icon icon-fav"
    )
    assert_equal expected, watcher_link(Issue.find(1), User.find(1))
  end
end
