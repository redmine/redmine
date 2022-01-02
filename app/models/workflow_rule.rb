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

class WorkflowRule < ActiveRecord::Base
  self.table_name = "#{table_name_prefix}workflows#{table_name_suffix}"

  belongs_to :role
  belongs_to :tracker
  belongs_to :old_status, :class_name => 'IssueStatus'
  belongs_to :new_status, :class_name => 'IssueStatus'

  validates_presence_of :role, :tracker

  # Copies workflows from source to targets
  def self.copy(source_tracker, source_role, target_trackers, target_roles)
    unless source_tracker.is_a?(Tracker) || source_role.is_a?(Role)
      raise ArgumentError.new(
        "source_tracker or source_role must be specified, given: " \
          "#{source_tracker.class.name} and #{source_role.class.name}"
      )
    end

    target_trackers = [target_trackers].flatten.compact
    target_roles = [target_roles].flatten.compact

    target_trackers = Tracker.sorted.to_a if target_trackers.empty?
    target_roles = Role.all.select(&:consider_workflow?) if target_roles.empty?

    target_trackers.each do |target_tracker|
      target_roles.each do |target_role|
        copy_one(source_tracker || target_tracker,
                 source_role || target_role,
                 target_tracker,
                 target_role)
      end
    end
  end

  # Copies a single set of workflows from source to target
  def self.copy_one(source_tracker, source_role, target_tracker, target_role)
    unless source_tracker.is_a?(Tracker) && !source_tracker.new_record? &&
      source_role.is_a?(Role) && !source_role.new_record? &&
      target_tracker.is_a?(Tracker) && !target_tracker.new_record? &&
      target_role.is_a?(Role) && !target_role.new_record?

      raise ArgumentError.new("arguments can not be nil or unsaved objects")
    end

    if source_tracker == target_tracker && source_role == target_role
      false
    else
      transaction do
        where(:tracker_id => target_tracker.id, :role_id => target_role.id).delete_all
        connection.insert(
          "INSERT INTO #{WorkflowRule.table_name}" \
            " (tracker_id, role_id, old_status_id, new_status_id," \
             " author, assignee, field_name, #{connection.quote_column_name 'rule'}, type)" \
            " SELECT #{target_tracker.id}, #{target_role.id}, old_status_id, new_status_id," \
                    " author, assignee, field_name, #{connection.quote_column_name 'rule'}, type" \
              " FROM #{WorkflowRule.table_name}" \
              " WHERE tracker_id = #{source_tracker.id} AND role_id = #{source_role.id}"
        )
      end
      true
    end
  end
end
