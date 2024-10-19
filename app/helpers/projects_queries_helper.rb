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
module ProjectsQueriesHelper
  include ApplicationHelper

  def column_value(column, item, value)
    if item.is_a?(Project)
      case column.name
      when :name
        link_to_project(item) +
          (tag.span(sprite_icon('user', l(:label_my_projects), icon_only: true), class: 'icon-only icon-user my-project') if User.current.member_of?(item)) +
          (tag.span(sprite_icon('bookmarked', l(:label_my_bookmarks), icon_only: true), class: 'icon-only icon-bookmarked-project') if User.current.bookmarked_project_ids.include?(item.id))
      when :short_description
        if item.description?
          # Sets :inline_attachments to false to avoid performance issues
          # caused by unnecessary loading of attachments
          content_tag('div', textilizable(item, :short_description, :inline_attachments => false), :class => 'wiki')
        else
          ''
        end
      when :homepage
        item.homepage? ? content_tag('div', textilizable(item, :homepage), :class => "wiki") : ''
      when :status
        get_project_status_label[column.value_object(item)]
      when :parent_id
        link_to_project(item.parent) unless item.parent.nil?
      when :last_activity_date
        formatted_value = super
        if value.present? && formatted_value.present?
          link_to(
            formatted_value,
            project_activity_path(item, :from => User.current.time_to_date(value))
          )
        else
          formatted_value
        end
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
