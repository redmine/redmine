# Redmine - project management software
# Copyright (C) 2006-2016  Jean-Philippe Lang
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

class IssuePriority < Enumeration
  has_many :issues, :foreign_key => 'priority_id'

  after_destroy {|priority| priority.class.compute_position_names}
  after_save {|priority| priority.class.compute_position_names if (priority.position_changed? && priority.position) || priority.active_changed?}

  OptionName = :enumeration_issue_priorities

  def option_name
    OptionName
  end

  def objects_count
    issues.count
  end

  def transfer_relations(to)
    issues.update_all(:priority_id => to.id)
  end

  def css_classes
    "priority-#{id} priority-#{position_name}"
  end

  # Clears position_name for all priorities
  # Called from migration 20121026003537_populate_enumerations_position_name
  def self.clear_position_names
    update_all :position_name => nil
  end

  # Updates position_name for active priorities
  # Called from migration 20121026003537_populate_enumerations_position_name
  def self.compute_position_names
    priorities = where(:active => true).sort_by(&:position)
    if priorities.any?
      default = priorities.detect(&:is_default?) || priorities[(priorities.size - 1) / 2]
      priorities.each_with_index do |priority, index|
        name = case
          when priority.position == default.position
            "default"
          when priority.position < default.position
            index == 0 ? "lowest" : "low#{index+1}"
          else
            index == (priorities.size - 1) ? "highest" : "high#{priorities.size - index}"
          end

        where(:id => priority.id).update_all({:position_name => name})
      end
    end
  end
end
