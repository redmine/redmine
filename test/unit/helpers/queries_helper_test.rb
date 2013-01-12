# Redmine - project management software
# Copyright (C) 2006-2013  Jean-Philippe Lang
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

class QueriesHelperTest < ActionView::TestCase
  include QueriesHelper
  include Redmine::I18n

  fixtures :projects, :enabled_modules, :users, :members,
           :member_roles, :roles, :trackers, :issue_statuses,
           :issue_categories, :enumerations, :issues,
           :watchers, :custom_fields, :custom_values, :versions,
           :queries,
           :projects_trackers,
           :custom_fields_trackers

  def test_order
    User.current = User.find_by_login('admin')
    query = IssueQuery.new(:project => nil, :name => '_')
    assert_equal 30, query.available_filters.size
    fo = filters_options(query)
    assert_equal 31, fo.size
    assert_equal [], fo[0]
    assert_equal "status_id", fo[1][1]
    assert_equal "project_id", fo[2][1]
    assert_equal "tracker_id", fo[3][1]
    assert_equal "priority_id", fo[4][1]
    assert_equal "watcher_id", fo[17][1]
    assert_equal "is_private", fo[18][1]
  end

  def test_order_custom_fields
    set_language_if_valid 'en'
    field = UserCustomField.new(
              :name => 'order test', :field_format => 'string',
              :is_for_all => true, :is_filter => true
            )
    assert field.save
    User.current = User.find_by_login('admin')
    query = IssueQuery.new(:project => nil, :name => '_')
    assert_equal 32, query.available_filters.size
    fo = filters_options(query)
    assert_equal 33, fo.size
    assert_equal "Searchable field", fo[19][0]
    assert_equal "Database", fo[20][0]
    assert_equal "Project's Development status", fo[21][0]
    assert_equal "Assignee's order test", fo[22][0]
    assert_equal "Author's order test", fo[23][0]
  end
end
