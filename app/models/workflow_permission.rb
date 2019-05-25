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

class WorkflowPermission < WorkflowRule
  validates_inclusion_of :rule, :in => %w(readonly required)
  validates_presence_of :old_status
  validate :validate_field_name

  # Returns the workflow permissions for the given trackers and roles
  # grouped by status_id
  #
  # Example:
  #   WorkflowPermission.rules_by_status_id trackers, roles
  #   # => {1 => {'start_date' => 'required', 'due_date' => 'readonly'}}
  def self.rules_by_status_id(trackers, roles)
    WorkflowPermission.where(:tracker_id => trackers.map(&:id), :role_id => roles.map(&:id)).inject({}) do |h, w|
      h[w.old_status_id] ||= {}
      h[w.old_status_id][w.field_name] ||= []
      h[w.old_status_id][w.field_name] << w.rule
      h
    end
  end

  # Replaces the workflow permissions for the given trackers and roles
  #
  # Example:
  #   WorkflowPermission.replace_permissions trackers, roles, {'1' => {'start_date' => 'required', 'due_date' => 'readonly'}}
  def self.replace_permissions(trackers, roles, permissions)
    trackers = Array.wrap trackers
    roles = Array.wrap roles

    transaction do
      permissions.each { |status_id, rule_by_field|
        rule_by_field.each { |field, rule|
          where(:tracker_id => trackers.map(&:id), :role_id => roles.map(&:id), :old_status_id => status_id, :field_name => field).destroy_all
          if rule.present?
            trackers.each do |tracker|
              roles.each do |role|
                WorkflowPermission.create(:role_id => role.id, :tracker_id => tracker.id, :old_status_id => status_id, :field_name => field, :rule => rule)
              end
            end
          end
        }
      }
    end
  end

  protected

  def validate_field_name
    unless Tracker::CORE_FIELDS_ALL.include?(field_name) || /^\d+$/.match?(field_name.to_s)
      errors.add :field_name, :invalid
    end
  end
end
