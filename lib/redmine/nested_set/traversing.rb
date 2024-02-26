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

module Redmine
  module NestedSet
    module Traversing
      def self.included(base)
        base.class_eval do
          scope :roots, lambda {where :parent_id => nil}
          scope :leaves, lambda {where "#{table_name}.rgt - #{table_name}.lft = ?", 1}
        end
      end

      # Returns true if the element has no parent
      def root?
        parent_id.nil?
      end

      # Returns true if the element has a parent
      def child?
        !root?
      end

      # Returns true if the element has no children
      def leaf?
        new_record? || (rgt - lft == 1)
      end

      # Returns the root element (ancestor with no parent)
      def root
        self_and_ancestors.first
      end

      # Returns the children
      def children
        if id.nil?
          nested_set_scope.none
        else
          self.class.order(:lft).where(:parent_id => id)
        end
      end

      # Returns the descendants that have no children
      def leaves
        descendants.where("#{self.class.table_name}.rgt - #{self.class.table_name}.lft = ?", 1)
      end

      # Returns the siblings
      def siblings
        nested_set_scope.where(:parent_id => parent_id).where("#{self.class.table_name}.id <> ?", id)
      end

      # Returns the ancestors
      def ancestors
        if root?
          nested_set_scope.none
        else
          nested_set_scope.where("#{self.class.table_name}.lft < ? AND #{self.class.table_name}.rgt > ?", lft, rgt)
        end
      end

      # Returns the element and its ancestors
      def self_and_ancestors
        nested_set_scope.where("#{self.class.table_name}.lft <= ? AND #{self.class.table_name}.rgt >= ?", lft, rgt)
      end

      # Returns true if the element is an ancestor of other
      def is_ancestor_of?(other)
        same_nested_set_scope?(other) && other.lft > lft && other.rgt < rgt
      end

      # Returns true if the element equals other or is an ancestor of other
      def is_or_is_ancestor_of?(other)
        other == self || is_ancestor_of?(other)
      end

      # Returns the descendants
      def descendants
        if leaf?
          nested_set_scope.none
        else
          nested_set_scope.where("#{self.class.table_name}.lft > ? AND #{self.class.table_name}.rgt < ?", lft, rgt)
        end
      end

      # Returns the element and its descendants
      def self_and_descendants
        nested_set_scope.where("#{self.class.table_name}.lft >= ? AND #{self.class.table_name}.rgt <= ?", lft, rgt)
      end

      # Returns true if the element is a descendant of other
      def is_descendant_of?(other)
        same_nested_set_scope?(other) && other.lft < lft && other.rgt > rgt
      end

      # Returns true if the element equals other or is a descendant of other
      def is_or_is_descendant_of?(other)
        other == self || is_descendant_of?(other)
      end

      # Returns the ancestors, the element and its descendants
      def hierarchy
        nested_set_scope.where(
          "#{self.class.table_name}.lft >= :lft AND #{self.class.table_name}.rgt <= :rgt" +
          " OR #{self.class.table_name}.lft < :lft AND #{self.class.table_name}.rgt > :rgt",
          {:lft => lft, :rgt => rgt})
      end
    end
  end
end
