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

class CustomFieldValue
  attr_accessor :custom_field, :customized, :value_was
  attr_reader   :value

  def initialize(attributes={})
    attributes.each do |name, v|
      send "#{name}=", v
    end
  end

  def custom_field_id
    custom_field.id
  end

  def true?
    self.value == '1'
  end

  def editable?
    custom_field.editable?
  end

  def visible?
    custom_field.visible?
  end

  def required?
    custom_field.is_required?
  end

  def to_s
    value.to_s
  end

  def value=(v)
    @value = custom_field.set_custom_field_value(self, v)
  end

  def value_present?
    if value.is_a?(Array)
      value.any?(&:present?)
    else
      value.present?
    end
  end

  def validate_value
    custom_field.validate_custom_value(self).each do |message|
      customized.errors.add(custom_field.name, message)
    end
  end
end
