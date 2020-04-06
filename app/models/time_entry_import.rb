# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2019  Jean-Philippe Lang
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

class TimeEntryImport < Import
  def self.menu_item
    :time_entries
  end

  def self.authorized?(user)
    user.allowed_to?(:import_time_entries, nil, :global => true)
  end

  # Returns the objects that were imported
  def saved_objects
    TimeEntry.where(:id => saved_items.pluck(:obj_id)).order(:id).preload(:activity, :project, :issue => [:tracker, :priority, :status])
  end

  def mappable_custom_fields
    TimeEntryCustomField.all
  end

  def allowed_target_projects
    Project.allowed_to(user, :log_time).order(:lft)
  end

  def allowed_target_activities
    project.activities
  end

  def allowed_target_users
    users = []
    if project
      users = project.members.active.preload(:user)
      users = users.map(&:user).select{ |u| u.allowed_to?(:log_time, project) }
    end
    users << User.current if User.current.logged? && !users.include?(User.current)
    users
  end

  def project
    project_id = mapping['project_id'].to_i
    allowed_target_projects.find_by_id(project_id) || allowed_target_projects.first
  end

  def activity
    if mapping['activity'].to_s =~ /\Avalue:(\d+)\z/
      activity_id = $1.to_i
      allowed_target_activities.find_by_id(activity_id)
    end
  end

  def user_value
    if mapping['user_id'].to_s =~ /\Avalue:(\d+)\z/
      $1.to_i
    end
  end

  private

  def build_object(row, item)
    object = TimeEntry.new
    object.author = user

    activity_id = nil
    if activity
      activity_id = activity.id
    elsif activity_name = row_value(row, 'activity')
      activity_id = allowed_target_activities.named(activity_name).first.try(:id)
    end

    user_id = nil
    if user.allowed_to?(:log_time_for_other_users, project)
      if user_value
        user_id = user_value
      elsif user_name = row_value(row, 'user_id')
        user_id = Principal.detect_by_keyword(allowed_target_users, user_name).try(:id)
      end
    else
      user_id = user.id
    end

    attributes = {
      :project_id  => project.id,
      :activity_id => activity_id,
      :author_id   => user.id,
      :user_id     => user_id,

      :issue_id    => row_value(row, 'issue_id'),
      :spent_on    => row_date(row, 'spent_on'),
      :hours       => row_value(row, 'hours'),
      :comments    => row_value(row, 'comments')
    }

    attributes['custom_field_values'] = object.custom_field_values.inject({}) do |h, v|
      value =
        case v.custom_field.field_format
        when 'date'
          row_date(row, "cf_#{v.custom_field.id}")
        else
          row_value(row, "cf_#{v.custom_field.id}")
        end
      if value
        h[v.custom_field.id.to_s] = v.custom_field.value_from_keyword(value, object)
      end
      h
    end

    object.send(:safe_attributes=, attributes, user)
    object
  end
end
