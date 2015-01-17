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

require File.expand_path('../../../test_helper', __FILE__)

class GroupsHelperTest < ActionView::TestCase
  include Redmine::I18n
  include ERB::Util
  include GroupsHelper

  fixtures :users

  def test_render_principals_for_new_group_users
    group = Group.generate!

    result = render_principals_for_new_group_users(group)
    assert_select_in result, 'input[name=?][value="2"]', 'user_ids[]'
  end

  def test_render_principals_for_new_group_users_with_limited_results_should_paginate
    group = Group.generate!

    result = render_principals_for_new_group_users(group, 3)
    assert_select_in result, 'p.pagination'
    assert_select_in result, 'span.current.page', :text => '1'
    assert_select_in result, 'a[href=?]', "/groups/#{group.id}/autocomplete_for_user.js?page=2", :text => '2'
  end
end
