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

class WorkflowTransition < WorkflowRule
  validates_presence_of :new_status

  # Returns workflow transitions count by tracker and role
  def self.count_by_tracker_and_role
    counts = connection.select_all("SELECT role_id, tracker_id, count(id) AS c FROM #{table_name} WHERE type = 'WorkflowTransition' GROUP BY role_id, tracker_id")
    roles = Role.sorted.all
    trackers = Tracker.sorted.all

    result = []
    trackers.each do |tracker|
      t = []
      roles.each do |role|
        row = counts.detect {|c| c['role_id'].to_s == role.id.to_s && c['tracker_id'].to_s == tracker.id.to_s}
        t << [role, (row.nil? ? 0 : row['c'].to_i)]
      end
      result << [tracker, t]
    end

    result
  end
end
