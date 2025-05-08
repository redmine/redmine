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

module RolesHelper
  include ApplicationHelper

  def permissions_to_csv(roles, permissions)
    Redmine::Export::CSV.generate(:encoding => params[:encoding]) do |csv|
      # csv header fields
      headers = [l(:field_cvs_module), l(:label_permissions)] + roles.collect(&:name)
      csv << headers
      # csv lines
      perms_by_module = permissions.group_by {|p| p.project_module.to_s}
      perms_by_module.keys.sort.each do |mod|
        perms_by_module[mod].each do |p|
          names = [
            l_or_humanize(p.project_module.to_s, :prefix => 'project_module_'),
            l_or_humanize(p.name, :prefix => 'permission_').to_s,
          ]
          fields = names + roles.collect do |role|
            if role.setable_permissions.include?(p)
              format_object(role.permissions.include?(p.name), html: false)
            else
              ''
            end
          end
          csv << fields
        end
      end
    end
  end
end
