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

class WorkflowTest < ActiveSupport::TestCase
  fixtures :roles, :trackers, :issue_statuses

  def setup
    User.current = nil
  end

  def test_copy
    WorkflowTransition.delete_all
    WorkflowTransition.create!(:role_id => 1, :tracker_id => 2,
                               :old_status_id => 1, :new_status_id => 2)
    WorkflowTransition.create!(:role_id => 1, :tracker_id => 2,
                               :old_status_id => 1, :new_status_id => 3,
                               :assignee => true)
    WorkflowTransition.create!(:role_id => 1, :tracker_id => 2,
                               :old_status_id => 1, :new_status_id => 4,
                               :author => true)

    assert_difference 'WorkflowTransition.count', 3 do
      WorkflowTransition.copy(Tracker.find(2), Role.find(1), Tracker.find(3), Role.find(2))
    end

    assert WorkflowTransition.where(:role_id => 2, :tracker_id => 3,
                                    :old_status_id => 1, :new_status_id => 2,
                                    :author => false, :assignee => false).first
    assert WorkflowTransition.where(:role_id => 2, :tracker_id => 3,
                                    :old_status_id => 1, :new_status_id => 3,
                                    :author => false, :assignee => true).first
    assert WorkflowTransition.where(:role_id => 2, :tracker_id => 3,
                                    :old_status_id => 1, :new_status_id => 4,
                                    :author => true, :assignee => false).first
  end

  def test_workflow_permission_should_validate_rule
    wp = WorkflowPermission.new(:role_id => 1, :tracker_id => 1,
                                :old_status_id => 1, :field_name => 'due_date')
    assert !wp.save

    wp.rule = 'foo'
    assert !wp.save

    wp.rule = 'required'
    assert wp.save

    wp.rule = 'readonly'
    assert wp.save
  end

  def test_workflow_permission_should_validate_field_name
    wp = WorkflowPermission.new(:role_id => 1, :tracker_id => 1,
                                :old_status_id => 1, :rule => 'required')
    assert !wp.save

    wp.field_name = 'foo'
    assert !wp.save

    wp.field_name = 'due_date'
    assert wp.save

    wp.field_name = '1'
    assert wp.save
  end
end
