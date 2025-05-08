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
end
