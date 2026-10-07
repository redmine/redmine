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

class MembersHelperTest < Redmine::HelperTest
  include ERB::Util
  include MembersHelper
  include AvatarsHelper

  def test_render_principals_for_new_members
    project = Project.generate!

    result = render_principals_for_new_members(project)
    assert_select_in result, 'input[name=?][value="2"]', 'membership[user_ids][]'
  end

  def test_render_principals_for_new_members_with_limited_results_should_paginate
    project = Project.generate!

    result = render_principals_for_new_members(project, 3)
    assert_select_in result, 'span.pagination'
    assert_select_in result, 'span.pagination li.current span', :text => '1'
    assert_select_in result, 'a[href=?]', "/projects/#{project.identifier}/memberships/autocomplete.js?page=2", :text => '2'
  end

  def test_paginate_members_returns_only_the_requested_page
    # per_page_option is provided by ApplicationController in the running app
    stubs(:per_page_option).returns(3)
    project = Project.generate!
    5.times { User.add_to_project(User.generate!, project) }

    members, member_pages, member_count = paginate_members(project.memberships)

    assert_equal 3, members.size
    assert_equal 3, member_pages.per_page
    assert_equal project.memberships.count, member_count
  end

  def test_paginate_members_lists_a_member_with_several_roles_once
    stubs(:per_page_option).returns(3)
    project = Project.generate!
    3.times { User.add_to_project(User.generate!, project) }
    Member.where(:project_id => project.id).first.update!(:role_ids => [1, 2])

    members, _member_pages, member_count = paginate_members(project.memberships)

    member_ids = members.map(&:id)
    assert_equal member_ids.uniq, member_ids
    assert_equal member_count, members.size
    assert_equal project.memberships.count, member_count
  end

  def test_paginate_members_should_paginate_the_given_scope
    stubs(:per_page_option).returns(25)
    project = Project.find(1)

    members, _member_pages, member_count = paginate_members(project.memberships.with_role(2))

    assert_equal [2, 4], members.map(&:id).sort
    assert_equal 2, member_count
  end

  def test_member_status_options
    expected = [
      [l(:label_all), ''],
      [l(:status_active), '1'],
      [l(:status_locked), '3']
    ]
    assert_equal expected, member_status_options
  end

  def test_members_scope_default_should_return_all_members
    project = Project.find(1)
    stubs(:params).returns({})

    assert_equal [1, 2, 4], members_scope(project).ids.sort
  end

  def test_members_scope_with_status_active_should_filter_by_active_status
    project = Project.find(1)
    stubs(:params).returns({:member_status => '1'})

    assert_equal [1, 2], members_scope(project).ids.sort
  end

  def test_members_scope_with_status_locked_should_return_locked_members
    project = Project.find(1)
    stubs(:params).returns({:member_status => '3'})

    assert_equal [4], members_scope(project).ids.sort
  end
end
