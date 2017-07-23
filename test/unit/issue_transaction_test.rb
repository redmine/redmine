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

class IssueTransactionTest < ActiveSupport::TestCase
  fixtures :projects, :users, :members, :member_roles, :roles,
           :trackers, :projects_trackers,
           :versions,
           :issue_statuses, :issue_categories, :issue_relations, :workflows,
           :enumerations,
           :issues,
           :custom_fields, :custom_fields_projects, :custom_fields_trackers, :custom_values,
           :time_entries

  self.use_transactional_tests = false

  def test_invalid_move_to_another_project
    lft1 = new_issue_lft
    parent1 = Issue.generate!
    child =   Issue.generate!(:parent_issue_id => parent1.id)
    grandchild = Issue.generate!(:parent_issue_id => child.id, :tracker_id => 2)
    Project.find(2).tracker_ids = [1]
    parent1.reload
    assert_equal [1, parent1.id, lft1, lft1 + 5], [parent1.project_id, parent1.root_id, parent1.lft, parent1.rgt]
    # child can not be moved to Project 2 because its child is on a disabled tracker
    child = Issue.find(child.id)
    child.project = Project.find(2)
    assert !child.save
    child.reload
    grandchild.reload
    parent1.reload
    # no change
    assert_equal [1, parent1.id, lft1,     lft1 + 5], [parent1.project_id, parent1.root_id, parent1.lft, parent1.rgt]
    assert_equal [1, parent1.id, lft1 + 1, lft1 + 4], [child.project_id, child.root_id, child.lft, child.rgt]
    assert_equal [1, parent1.id, lft1 + 2, lft1 + 3], [grandchild.project_id, grandchild.root_id, grandchild.lft, grandchild.rgt]
  end
end
