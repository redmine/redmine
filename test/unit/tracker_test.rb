# Redmine - project management software
# Copyright (C) 2006-2008  Jean-Philippe Lang
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

class TrackerTest < ActiveSupport::TestCase
  fixtures :trackers, :workflows, :issue_statuses, :roles

  def test_copy_workflows
    source = Tracker.find(1)
    assert_equal 89, source.workflows.size

    target = Tracker.new(:name => 'Target')
    assert target.save
    target.workflows.copy(source)
    target.reload
    assert_equal 89, target.workflows.size
  end

  def test_issue_statuses
    tracker = Tracker.find(1)
    Workflow.delete_all
    Workflow.create!(:role_id => 1, :tracker_id => 1, :old_status_id => 2, :new_status_id => 3)
    Workflow.create!(:role_id => 2, :tracker_id => 1, :old_status_id => 3, :new_status_id => 5)

    assert_kind_of Array, tracker.issue_statuses
    assert_kind_of IssueStatus, tracker.issue_statuses.first
    assert_equal [2, 3, 5], Tracker.find(1).issue_statuses.collect(&:id)
  end

  def test_issue_statuses_empty
    Workflow.delete_all("tracker_id = 1")
    assert_equal [], Tracker.find(1).issue_statuses
  end

  def test_issue_statuses_should_be_empty_for_new_record
    assert_equal [], Tracker.new.issue_statuses
  end

  def test_sort_should_sort_by_position
    a = Tracker.new(:name => 'Tracker A', :position => 2)
    b = Tracker.new(:name => 'Tracker B', :position => 1)

    assert_equal [b, a], [a, b].sort
  end
end
