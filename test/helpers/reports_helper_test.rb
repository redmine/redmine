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

class ReportsHlperTest < Redmine::HelperTest
  include ReportsHelper

  def test_aggregate_path_for_spacified_row
    project = Project.find(1)
    field = 'assigned_to_id'
    row = User.find(2)
    assert_equal '/projects/ecookbook/issues?assigned_to_id=2&set_filter=1&subproject_id=%21%2A', aggregate_path(project, field, row)
  end

  def test_aggregate_path_for_unset_row
    project = Project.find(1)
    field = 'assigned_to_id'
    row = User.new
    assert_equal '/projects/ecookbook/issues?assigned_to_id=%21%2A&set_filter=1&subproject_id=%21%2A', aggregate_path(project, field, row)
  end
end
