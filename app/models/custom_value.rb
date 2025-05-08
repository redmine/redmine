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

class CustomValue < ApplicationRecord
  belongs_to :custom_field
  belongs_to :customized, :polymorphic => true

  after_save :custom_field_after_save_custom_value

  def initialize(attributes=nil, *args)
    super
    if new_record? && custom_field && !attributes.key?(:value) && (customized.nil? || customized.set_custom_field_default?(self))
      self.value ||= custom_field.default_value
    end
  end

  # Returns true if the boolean custom value is true
  def true?
    self.value == '1'
  end

  def editable?
    custom_field.editable?
  end

  def visible?(user=User.current)
    if custom_field.visible?
      true
    elsif customized.respond_to?(:project)
      custom_field.visible_by?(customized.project, user)
    else
      false
    end
  end

  def attachments_visible?(user)
    visible?(user) && customized && customized.visible?(user)
  end

  def required?
    custom_field.is_required?
  end

  def to_s
    value.to_s
  end

  private

  def custom_field_after_save_custom_value
    custom_field.after_save_custom_value(self)
  end
end
