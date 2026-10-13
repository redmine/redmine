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

class NonWorkingDateImport < Import
  AUTO_MAPPABLE_FIELDS = {
    'date' => 'field_date',
    'name' => 'field_name'
  }

  def self.menu_item
    :settings
  end

  def self.layout
    'admin'
  end

  def self.authorized?(user)
    user.admin?
  end

  # Returns the objects that were imported
  def saved_objects
    NonWorkingDate.where(:id => saved_items.pluck(:obj_id)).sorted
  end

  def mappable_custom_fields
    []
  end

  private

  def build_object(row, item)
    NonWorkingDate.new(
      :date => row_date(row, 'date'),
      :name => row_value(row, 'name')
    )
  end
end
