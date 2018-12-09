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

class WorkflowTransitionTest < ActiveSupport::TestCase
  fixtures :roles, :trackers, :issue_statuses

  def setup
    WorkflowTransition.delete_all
  end

  def test_replace_transitions_should_create_enabled_transitions
    w = WorkflowTransition.create!(:role_id => 1, :tracker_id => 1, :old_status_id => 1, :new_status_id => 2)

    transitions = {'1' => {
      '2' => {'always' => '1'},
      '3' => {'always' => '1'}
    }}
    assert_difference 'WorkflowTransition.count' do
      WorkflowTransition.replace_transitions(Tracker.find(1), Role.find(1), transitions)
    end
    assert WorkflowTransition.where(:role_id => 1, :tracker_id => 1, :old_status_id => 1, :new_status_id => 3).exists?
  end

  def test_replace_transitions_should_delete_disabled_transitions
    w1 = WorkflowTransition.create!(:role_id => 1, :tracker_id => 1, :old_status_id => 1, :new_status_id => 2)
    w2 = WorkflowTransition.create!(:role_id => 1, :tracker_id => 1, :old_status_id => 1, :new_status_id => 3)

    transitions = {'1' => {
      '2' => {'always' => '0'},
      '3' => {'always' => '1'}
    }}
    assert_difference 'WorkflowTransition.count', -1 do
      WorkflowTransition.replace_transitions(Tracker.find(1), Role.find(1), transitions)
    end
    assert !WorkflowTransition.exists?(w1.id)
  end

  def test_replace_transitions_should_create_enabled_additional_transitions
    transitions = {'1' => {
      '2' => {'always' => '0', 'assignee' => '0', 'author' => '1'}
    }}
    assert_difference 'WorkflowTransition.count' do
      WorkflowTransition.replace_transitions(Tracker.find(1), Role.find(1), transitions)
    end
    w = WorkflowTransition.where(:role_id => 1, :tracker_id => 1, :old_status_id => 1, :new_status_id => 2).first
    assert w
    assert_equal false, w.assignee
    assert_equal true, w.author
  end

  def test_replace_transitions_should_delete_disabled_additional_transitions
    w = WorkflowTransition.create!(:role_id => 1, :tracker_id => 1, :old_status_id => 1, :new_status_id => 2, :assignee => true)

    transitions = {'1' => {
      '2' => {'always' => '0', 'assignee' => '0', 'author' => '0'}
    }}
    assert_difference 'WorkflowTransition.count', -1 do
      WorkflowTransition.replace_transitions(Tracker.find(1), Role.find(1), transitions)
    end
    assert !WorkflowTransition.exists?(w.id)
  end

  def test_replace_transitions_should_update_additional_transitions
    WorkflowTransition.create!(:role_id => 1, :tracker_id => 1, :old_status_id => 1, :new_status_id => 2, :assignee => true)

    transitions = {'1' => {
      '2' => {'always' => '0', 'assignee' => '0', 'author' => '1'}
    }}
    assert_no_difference 'WorkflowTransition.count' do
      WorkflowTransition.replace_transitions(Tracker.find(1), Role.find(1), transitions)
    end
    w = WorkflowTransition.where(:role_id => 1, :tracker_id => 1, :old_status_id => 1, :new_status_id => 2).first
    assert w
    assert_equal false, w.assignee
    assert_equal true, w.author
  end
end
