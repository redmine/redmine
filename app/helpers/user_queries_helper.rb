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

module UserQueriesHelper
  def column_value(column, object, value)
    if object.is_a?(User) && column.name == :status
      user_status_label(column.value_object(object))
    else
      super
    end
  end

  def csv_value(column, object, value)
    if object.is_a?(User)
      case column.name
      when :status
        user_status_label(column.value_object(object))
      when :twofa_scheme
        twofa_scheme_label value
      else
        super
      end
    else
      super
    end
  end

  def user_status_label(value)
    case value.to_i
    when User::STATUS_ACTIVE
      l(:status_active)
    when User::STATUS_REGISTERED
      l(:status_registered)
    when User::STATUS_LOCKED
      l(:status_locked)
    end
  end

  def twofa_scheme_label(value)
    if value
      ::I18n.t :"twofa__#{value}__name"
    else
      ::I18n.t :label_disabled
    end
  end
end
