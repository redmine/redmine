# Redmine - project management software
# Copyright (C) 2006-2015  Jean-Philippe Lang
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

class Enumeration < ActiveRecord::Base
  include Redmine::SubclassFactory

  default_scope lambda {order(:position)}

  belongs_to :project

  acts_as_list :scope => 'type = \'#{type}\' AND #{parent_id ? "parent_id = #{parent_id}" : "parent_id IS NULL"}'
  acts_as_customizable
  acts_as_tree

  before_destroy :check_integrity
  before_save    :check_default

  attr_protected :type

  validates_presence_of :name
  validates_uniqueness_of :name, :scope => [:type, :project_id]
  validates_length_of :name, :maximum => 30

  scope :shared, lambda { where(:project_id => nil) }
  scope :sorted, lambda { order(:position) }
  scope :active, lambda { where(:active => true) }
  scope :system, lambda { where(:project_id => nil) }
  scope :named, lambda {|arg| where("LOWER(#{table_name}.name) = LOWER(?)", arg.to_s.strip)}

  def self.default
    # Creates a fake default scope so Enumeration.default will check
    # it's type.  STI subclasses will automatically add their own
    # types to the finder.
    if self.descends_from_active_record?
      where(:is_default => true, :type => 'Enumeration').first
    else
      # STI classes are
      where(:is_default => true).first
    end
  end

  # Overloaded on concrete classes
  def option_name
    nil
  end

  def check_default
    if is_default? && is_default_changed?
      Enumeration.where({:type => type}).update_all({:is_default => false})
    end
  end

  # Overloaded on concrete classes
  def objects_count
    0
  end

  def in_use?
    self.objects_count != 0
  end

  # Is this enumeration overriding a system level enumeration?
  def is_override?
    !self.parent.nil?
  end

  alias :destroy_without_reassign :destroy

  # Destroy the enumeration
  # If a enumeration is specified, objects are reassigned
  def destroy(reassign_to = nil)
    if reassign_to && reassign_to.is_a?(Enumeration)
      self.transfer_relations(reassign_to)
    end
    destroy_without_reassign
  end

  def <=>(enumeration)
    position <=> enumeration.position
  end

  def to_s; name end

  # Returns the Subclasses of Enumeration.  Each Subclass needs to be
  # required in development mode.
  #
  # Note: subclasses is protected in ActiveRecord
  def self.get_subclasses
    subclasses
  end

  # Does the +new+ Hash override the previous Enumeration?
  def self.overriding_change?(new, previous)
    if (same_active_state?(new['active'], previous.active)) && same_custom_values?(new,previous)
      return false
    else
      return true
    end
  end

  # Does the +new+ Hash have the same custom values as the previous Enumeration?
  def self.same_custom_values?(new, previous)
    previous.custom_field_values.each do |custom_value|
      if custom_value.value != new["custom_field_values"][custom_value.custom_field_id.to_s]
        return false
      end
    end

    return true
  end

  # Are the new and previous fields equal?
  def self.same_active_state?(new, previous)
    new = (new == "1" ? true : false)
    return new == previous
  end

  # Overrides acts_as_list reset_positions_in_list so that enumeration overrides
  # get the same position as the overriden enumeration
  def reset_positions_in_list
    acts_as_list_class.where(scope_condition).reorder("#{position_column} ASC, id ASC").each_with_index do |item, i|
      acts_as_list_class.where("id = :id OR parent_id = :id", :id => item.id).
        update_all({position_column => (i + 1)})
    end
  end

private
  def check_integrity
    raise "Cannot delete enumeration" if self.in_use?
  end

  # Overrides acts_as_list add_to_list_bottom so that enumeration overrides
  # get the same position as the overriden enumeration
  def add_to_list_bottom
    if parent
      self[position_column] = parent.position
    else
      super
    end
  end

  # Overrides acts_as_list remove_from_list so that enumeration overrides
  # get the same position as the overriden enumeration
  def remove_from_list
    if parent_id.blank?
      super
    end
  end
end

# Force load the subclasses in development mode
require_dependency 'time_entry_activity'
require_dependency 'document_category'
require_dependency 'issue_priority'
