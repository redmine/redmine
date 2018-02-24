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

require File.expand_path('../../../../../../test_helper', __FILE__)

class IssuesPdfHelperTest < ActiveSupport::TestCase
  fixtures :users, :projects, :roles, :members, :member_roles,
           :enabled_modules, :issues, :trackers, :enumerations

  include Redmine::Export::PDF::IssuesPdfHelper

  def test_fetch_row_values_should_round_float_values
    query = IssueQuery.new(:project => Project.find(1), :name => '_')
    query.column_names = [:subject, :spent_hours]
    issue = Issue.find(2)
    TimeEntry.create(:spent_on => Date.today, :hours => 4.3432, :user => User.find(1),
                     :project_id => 1, :issue => issue, :activity => TimeEntryActivity.first)
    results = fetch_row_values(issue, query, 0)
    assert_equal ["2", "Add ingredients categories", "4.34"], results
  end
end
