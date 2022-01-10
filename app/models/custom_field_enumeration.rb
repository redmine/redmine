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

class CustomFieldEnumeration < ActiveRecord::Base
  belongs_to :custom_field

  validates_presence_of :name, :position, :custom_field_id
  validates_length_of :name, :maximum => 60
  validates_numericality_of :position, :only_integer => true
  before_create :set_position

  scope :active, lambda {where(:active => true)}

  def to_s
    name.to_s
  end

  def objects_count
    custom_values.count
  end

  def in_use?
    objects_count > 0
  end

  alias :destroy_without_reassign :destroy
  def destroy(reassign_to=nil)
    if reassign_to
      custom_values.update_all(:value => reassign_to.id.to_s)
    end
    destroy_without_reassign
  end

  def custom_values
    custom_field.custom_values.where(:value => id.to_s)
  end

  def self.update_each(custom_field, attributes)
    transaction do
      attributes.each do |enumeration_id, enumeration_attributes|
        enumeration = custom_field.enumerations.find_by_id(enumeration_id)
        if enumeration
          if block_given?
            yield enumeration, enumeration_attributes
          else
            enumeration.attributes = enumeration_attributes
          end
          unless enumeration.save
            raise ActiveRecord::Rollback
          end
        end
      end
    end
  end

  def self.fields_for_order_statement(table=nil)
    table ||= table_name
    columns = ['position']
    columns.uniq.map {|field| "#{table}.#{field}"}
  end

  private

  def set_position
    max = self.class.where(:custom_field_id => custom_field_id).maximum(:position) || 0
    self.position = max + 1
  end
end
