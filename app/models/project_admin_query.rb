# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) Jean-Philippe Lang
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

class ProjectAdminQuery < ProjectQuery
  self.layout = 'admin'

  def self.default(project: nil, user: User.current)
    nil
  end

  def self.visible(*args)
    user = args.shift || User.current
    if user.admin?
      where('1=1')
    else
      where('1=0')
    end
  end

  def visible?(user=User.current)
    user&.admin?
  end

  def editable_by?(user)
    user&.admin?
  end

  def available_display_types
    ['list']
  end

  def display_type
    'list'
  end

  def project_statuses_values
    values = super

    values << [l(:project_status_archived), Project::STATUS_ARCHIVED.to_s]
    values << [l(:project_status_scheduled_for_deletion), Project::STATUS_SCHEDULED_FOR_DELETION.to_s]
    values
  end

  def base_scope
    Project.where(statement)
  end
end
