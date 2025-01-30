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

class TimeEntryActivity < Enumeration
  has_many :time_entries, :foreign_key => 'activity_id'

  OptionName = :enumeration_activities

  def self.default(project=nil)
    default_activity = super()

    if default_activity.nil? || project.nil? || project.activities.blank? || project.activities.include?(default_activity)
      return default_activity
    end

    project.activities.detect { |activity| activity.parent_id == default_activity.id }
  end

  # Returns the available activities for the time entry
  def self.available_activities(project=nil)
    if project.nil?
      TimeEntryActivity.shared.active
    else
      project.activities
    end
  end

  def option_name
    OptionName
  end

  def objects
    TimeEntry.where(:activity_id => self_and_descendants(1).map(&:id))
  end

  def objects_count
    objects.count
  end

  def transfer_relations(to)
    objects.update_all(:activity_id => to.id)
  end

  def self.default_activity_id(user=nil, project=nil)
    available_activities = self.available_activities(project).load
    return nil if available_activities.empty?
    return available_activities.first.id if available_activities.one?

    find_matching_activity = ->(ids) do
      ids.each do |id|
        activity = available_activities.detect { |a| a.id == id || a.parent_id == id }
        return activity.id if activity
      end
      nil
    end

    if project && user
      if (user_membership = user.membership(project))
        activity_ids = user_membership.roles.where.not(:default_time_entry_activity_id => nil).sort.pluck(:default_time_entry_activity_id)
        aid = find_matching_activity.call(activity_ids)
        return aid if aid
      end

      if (project_default_activity = self.default(project))
        aid = find_matching_activity.call([project_default_activity.id])
        return aid if aid
      end
    end

    if (global_activity = self.default)
      aid = find_matching_activity.call([global_activity.id])
      return aid if aid
    end

    nil
  end
end
