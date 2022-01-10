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

module Redmine
  module NestedSet
    module IssueNestedSet
      def self.included(base)
        base.class_eval do
          belongs_to :parent, :class_name => self.name

          before_create :add_to_nested_set, :if => lambda {|issue| issue.parent.present?}
          after_create :add_as_root, :if => lambda {|issue| issue.parent.blank?}
          before_update :handle_parent_change, :if => lambda {|issue| issue.parent_id_changed?}
          before_destroy :destroy_children
        end
        base.extend ClassMethods
        base.send :include, Redmine::NestedSet::Traversing
      end

      private

      def target_lft
        scope_for_max_rgt = self.class.where(:root_id => root_id).where(:parent_id => parent_id)
        if id
          scope_for_max_rgt = scope_for_max_rgt.where("id < ?", id)
        end
        max_rgt = scope_for_max_rgt.maximum(:rgt)
        if max_rgt
          max_rgt + 1
        elsif parent
          parent.lft + 1
        else
          1
        end
      end

      def add_to_nested_set(lock=true)
        lock_nested_set if lock
        parent.send :reload_nested_set_values
        self.root_id = parent.root_id
        self.lft = target_lft
        self.rgt = lft + 1
        self.class.where(:root_id => root_id).where("lft >= ? OR rgt >= ?", lft, lft).update_all(
          [
            "lft = CASE WHEN lft >= :lft THEN lft + 2 ELSE lft END, " +
              "rgt = CASE WHEN rgt >= :lft THEN rgt + 2 ELSE rgt END",
            {:lft => lft}
          ]
        )
      end

      def add_as_root
        self.root_id = id
        self.lft = 1
        self.rgt = 2
        self.class.where(:id => id).update_all(:root_id => root_id, :lft => lft, :rgt => rgt)
      end

      def handle_parent_change
        lock_nested_set
        reload_nested_set_values
        if parent_id_was
          remove_from_nested_set
        end
        if parent
          move_to_nested_set
        end
        reload_nested_set_values
      end

      def move_to_nested_set
        if parent
          previous_root_id = root_id
          self.root_id = parent.root_id

          lft_after_move = target_lft
          self.class.where(:root_id => parent.root_id).update_all(
            [
              "lft = CASE WHEN lft >= :lft THEN lft + :shift ELSE lft END, " +
                "rgt = CASE WHEN rgt >= :lft THEN rgt + :shift ELSE rgt END",
              {:lft => lft_after_move, :shift => (rgt - lft + 1)}
            ]
          )
          self.class.where(:root_id => previous_root_id).update_all(
            [
              "root_id = :root_id, lft = lft + :shift, rgt = rgt + :shift",
              {:root_id => parent.root_id, :shift => lft_after_move - lft}
            ]
          )
          self.lft, self.rgt = lft_after_move, (rgt - lft + lft_after_move)
          parent.send :reload_nested_set_values
        end
      end

      def remove_from_nested_set
        self.class.where(:root_id => root_id).where("lft >= ? AND rgt <= ?", lft, rgt).
          update_all(["root_id = :id, lft = lft - :shift, rgt = rgt - :shift", {:id => id, :shift => lft - 1}])

        self.class.where(:root_id => root_id).update_all(
          [
            "lft = CASE WHEN lft >= :lft THEN lft - :shift ELSE lft END, " +
              "rgt = CASE WHEN rgt >= :lft THEN rgt - :shift ELSE rgt END",
            {:lft => lft, :shift => rgt - lft + 1}
          ]
        )
        self.root_id = id
        self.lft, self.rgt = 1, (rgt - lft + 1)
      end

      def destroy_children
        unless @without_nested_set_update
          lock_nested_set
          reload_nested_set_values
        end
        children.each {|c| c.send :destroy_without_nested_set_update}
        reload
        unless @without_nested_set_update
          self.class.where(:root_id => root_id).where("lft > ? OR rgt > ?", lft, lft).update_all(
            [
              "lft = CASE WHEN lft > :lft THEN lft - :shift ELSE lft END, " +
                "rgt = CASE WHEN rgt > :lft THEN rgt - :shift ELSE rgt END",
              {:lft => lft, :shift => rgt - lft + 1}
            ]
          )
        end
      end

      def destroy_without_nested_set_update
        @without_nested_set_update = true
        destroy
      end

      def reload_nested_set_values
        self.root_id, self.lft, self.rgt = self.class.where(:id => id).pick(:root_id, :lft, :rgt)
      end

      def save_nested_set_values
        self.class.where(:id => id).update_all(:root_id => root_id, :lft => lft, :rgt => rgt)
      end

      def move_possible?(issue)
        new_record? || !is_or_is_ancestor_of?(issue)
      end

      def lock_nested_set
        if /sqlserver/i.match?(self.class.connection.adapter_name)
          lock = "WITH (ROWLOCK HOLDLOCK UPDLOCK)"
          # Custom lock for SQLServer
          # This can be problematic if root_id or parent root_id changes
          # before locking
          sets_to_lock = [root_id, parent.try(:root_id)].compact.uniq
          self.class.reorder(:id).where(:root_id => sets_to_lock).lock(lock).ids
        else
          sets_to_lock = [id, parent_id].compact
          self.class.reorder(:id).where("root_id IN (SELECT root_id FROM #{self.class.table_name} WHERE id IN (?))", sets_to_lock).lock.ids
        end
      end

      def nested_set_scope
        self.class.order(:lft).where(:root_id => root_id)
      end

      def same_nested_set_scope?(issue)
        root_id == issue.root_id
      end

      module ClassMethods
        def rebuild_tree!
          transaction do
            reorder(:id).lock.ids
            update_all(:root_id => nil, :lft => nil, :rgt => nil)
            where(:parent_id => nil).update_all(["root_id = id, lft = ?, rgt = ?", 1, 2])
            roots_with_children = joins("JOIN #{table_name} parent ON parent.id = #{table_name}.parent_id AND parent.id = parent.root_id").distinct.pluck("parent.id")
            roots_with_children.each do |root_id|
              rebuild_nodes(root_id)
            end
          end
        end

        def rebuild_single_tree!(root_id)
          root = Issue.where(:parent_id => nil).find(root_id)
          transaction do
            where(root_id: root_id).reorder(:id).lock.ids
            where(root_id: root_id).update_all(:lft => nil, :rgt => nil)
            where(root_id: root_id, parent_id: nil).update_all(["lft = ?, rgt = ?", 1, 2])
            rebuild_nodes(root_id)
          end
        end

        private

        def rebuild_nodes(parent_id = nil)
          nodes = where(:parent_id => parent_id, :rgt => nil, :lft => nil).order(:id).to_a

          nodes.each do |node|
            node.send :add_to_nested_set, false
            node.send :save_nested_set_values
            rebuild_nodes node.id
          end
        end
      end
    end
  end
end
