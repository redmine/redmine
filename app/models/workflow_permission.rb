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

class WorkflowPermission < WorkflowRule
  validates_inclusion_of :rule, :in => %w(readonly required)
  validate :validate_field_name

  # Replaces the workflow permissions for the given tracker and role
  #
  # Example:
  #   WorkflowPermission.replace_permissions role, tracker, {'due_date' => {'1' => 'readonly', '2' => 'required'}}
  def self.replace_permissions(tracker, role, permissions)
    destroy_all(:tracker_id => tracker.id, :role_id => role.id)

    permissions.each { |field, rule_by_status_id|
      rule_by_status_id.each { |status_id, rule|
        if rule.present?
          WorkflowPermission.create(:role_id => role.id, :tracker_id => tracker.id, :old_status_id => status_id, :field_name => field, :rule => rule)
        end
      }
    }
  end

  protected

  def validate_field_name
    unless Tracker::CORE_FIELDS_ALL.include?(field_name) || field_name.to_s.match(/^\d+$/)
      errors.add :field_name, :invalid
    end
  end
end
