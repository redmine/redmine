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
    default_activities = []
    default_activity = nil
    available_activities = self.available_activities(project)

    if project && user
      user_membership = user.membership(project)
      if user_membership
        default_activities = user_membership.roles.where.not(:default_time_entry_activity_id => nil).sort.pluck(:default_time_entry_activity_id)
      end

      project_default_activity = self.default(project)
      if project_default_activity && !default_activities.include?(project_default_activity.id)
        default_activities << project_default_activity.id
      end
    end

    global_activity = self.default
    if global_activity && !default_activities.include?(global_activity.id)
      default_activities << global_activity.id
    end

    if available_activities.count == 1 && !default_activities.include?(available_activities.first.id)
      default_activities << available_activities.first.id
    end

    default_activities.each do |id|
      default_activity = available_activities.detect{ |a| a.id == id || a.parent_id == id }
      break unless default_activity.nil?
    end

    default_activity&.id
  end
end
