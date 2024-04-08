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

class IssueCategory < ActiveRecord::Base
  include Redmine::SafeAttributes
  belongs_to :project
  belongs_to :assigned_to, :class_name => 'Principal'
  has_many :issues, :foreign_key => 'category_id', :dependent => :nullify

  validates_presence_of :name
  validates_uniqueness_of :name, :scope => [:project_id], :case_sensitive => true
  validates_length_of :name, :maximum => 60

  safe_attributes 'name', 'assigned_to_id'

  scope :named, lambda {|arg| where("LOWER(#{table_name}.name) = LOWER(?)", arg.to_s.strip)}

  alias :destroy_without_reassign :destroy

  # Destroy the category
  # If a category is specified, issues are reassigned to this category
  def destroy(reassign_to = nil)
    if reassign_to && reassign_to.is_a?(IssueCategory) && reassign_to.project == self.project
      Issue.where({:category_id => id}).update_all({:category_id => reassign_to.id})
    end
    destroy_without_reassign
  end

  def <=>(category)
    return nil unless category.is_a?(IssueCategory)

    name <=> category.name
  end

  def to_s; name end
end
