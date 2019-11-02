# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2017  Jean-Philippe Lang
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
module ProjectsQueriesHelper
  include ApplicationHelper

  def column_value(column, item, value)
    if item.is_a?(Project)
      case column.name
      when :name
        link_to_project(item) + (content_tag('span', '', :class => 'icon icon-user my-project', :title => l(:label_my_projects)) if User.current.member_of?(item))
      when :short_description
        item.description? ? content_tag('div', textilizable(item, :short_description), :class => "wiki") : ''
      when :homepage
        item.homepage? ? content_tag('div', textilizable(item, :homepage), :class => "wiki") : ''
      when :status
        get_project_status_label[column.value_object(item)]
      when :parent_id
        link_to_project(item.parent) unless item.parent.nil?
      else
        super
      end
    end
  end

  def csv_value(column, object, value)
    if object.is_a?(Project)
      case column.name
      when :status
        get_project_status_label[column.value_object(object)]
      when :parent_id
        object.parent.name unless object.parent.nil?
      else
        super
      end
    end
  end

  private

  def get_project_status_label
    {
      Project::STATUS_ACTIVE => l(:project_status_active),
      Project::STATUS_CLOSED => l(:project_status_closed)
    }
  end
end
