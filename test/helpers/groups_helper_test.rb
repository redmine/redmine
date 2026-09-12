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

class GroupsHelperTest < Redmine::HelperTest
  include ERB::Util
  include GroupsHelper
  include AvatarsHelper

  def test_render_principals_for_new_group_users
    group = Group.generate!

    result = render_principals_for_new_group_users(group)
    assert_select_in result, 'input[name=?][value="2"]', 'user_ids[]'
  end

  def test_render_principals_for_new_group_users_with_limited_results_should_paginate
    group = Group.generate!

    result = render_principals_for_new_group_users(group, 3)
    assert_select_in result, 'span.pagination'
    assert_select_in result, 'span.pagination li.current span', :text => '1'
    assert_select_in result, 'a[href=?]', "/groups/#{group.id}/autocomplete_for_user.js?page=2", :text => '2'
  end

  def test_paginate_group_users_returns_only_the_requested_page
    # per_page_option is provided by ApplicationController in the running app
    stubs(:per_page_option).returns(2)
    group = Group.generate!
    3.times { group.users << User.generate! }

    users, user_pages, user_count = paginate_group_users(group)

    assert_equal 2, users.size
    assert_equal 2, user_pages.per_page
    assert_equal group.users.count, user_count
  end
end
