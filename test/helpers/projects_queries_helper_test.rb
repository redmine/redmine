# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2022  Jean-Philippe Lang
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

class ProjectsQueriesHelperTest < Redmine::HelperTest
  include ProjectsQueriesHelper

  fixtures :projects, :enabled_modules,
           :custom_fields, :custom_values

  def test_csv_value
    c_status = QueryColumn.new(:status)
    c_parent_id = QueryColumn.new(:parent_id)

    assert_equal "active", csv_value(c_status, Project.find(1), 1)
    assert_equal "eCookbook", csv_value(c_parent_id, Project.find(4), 1)
  end
end
