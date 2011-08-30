# Redmine - project management software
# Copyright (C) 2006-2011  Jean-Philippe Lang
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

  def test_copy
    Workflow.delete_all
    Workflow.create!(:role_id => 1, :tracker_id => 2, :old_status_id => 1, :new_status_id => 2)
    Workflow.create!(:role_id => 1, :tracker_id => 2, :old_status_id => 1, :new_status_id => 3, :assignee => true)
    Workflow.create!(:role_id => 1, :tracker_id => 2, :old_status_id => 1, :new_status_id => 4, :author => true)

    assert_difference 'Workflow.count', 3 do
      Workflow.copy(Tracker.find(2), Role.find(1), Tracker.find(3), Role.find(2))
    end

    assert Workflow.first(:conditions => {:role_id => 2, :tracker_id => 3, :old_status_id => 1, :new_status_id => 2, :author => false, :assignee => false})
    assert Workflow.first(:conditions => {:role_id => 2, :tracker_id => 3, :old_status_id => 1, :new_status_id => 3, :author => false, :assignee => true})
    assert Workflow.first(:conditions => {:role_id => 2, :tracker_id => 3, :old_status_id => 1, :new_status_id => 4, :author => true, :assignee => false})
  end
end
