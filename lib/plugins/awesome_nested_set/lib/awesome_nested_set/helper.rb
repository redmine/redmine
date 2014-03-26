# -*- coding: utf-8 -*-
module CollectiveIdea #:nodoc:
  module Acts #:nodoc:
    module NestedSet #:nodoc:
      # This module provides some helpers for the model classes using acts_as_nested_set.
      # It is included by default in all views.
      #
      module Helper
        # Returns options for select.
        # You can exclude some items from the tree.
        # You can pass a block receiving an item and returning the string displayed in the select.
        #
        # == Params
        #  * +class_or_item+ - Class name or top level times
        #  * +mover+ - The item that is being move, used to exlude impossible moves
        #  * +&block+ - a block that will be used to display: { |item| ... item.name }
        #
        # == Usage
        #
        #   <%= f.select :parent_id, nested_set_options(Category, @category) {|i|
        #       "#{'–' * i.level} #{i.name}"
        #     }) %>
        #
        def nested_set_options(class_or_item, mover = nil)
          if class_or_item.is_a? Array
            items = class_or_item.reject { |e| !e.root? }
          else
            class_or_item = class_or_item.roots if class_or_item.respond_to?(:scoped)
            items = Array(class_or_item)
          end
          result = []
          items.each do |root|
            result += root.class.associate_parents(root.self_and_descendants).map do |i|
              if mover.nil? || mover.new_record? || mover.move_possible?(i)
                [yield(i), i.id]
              end
            end.compact
          end
          result
        end
        
        # Returns options for select as nested_set_options, sorted by an specific column
        # It requires passing a string with the name of the column to sort the set with
        # You can exclude some items from the tree.
        # You can pass a block receiving an item and returning the string displayed in the select.
        #
        # == Params
        #  * +class_or_item+ - Class name or top level times
        #  * +:column+ - Column to sort the set (this will sort each children for all root elements)
        #  * +mover+ - The item that is being move, used to exlude impossible moves
        #  * +&block+ - a block that will be used to display: { |item| ... item.name }
        #
        # == Usage
        #
        #   <%= f.select :parent_id, nested_set_options(Category, :sort_by_this_column,  @category) {|i|
        #       "#{'–' * i.level} #{i.name}"
        #     }) %>
        #
        def sorted_nested_set_options(class_or_item, order, mover = nil)
          if class_or_item.is_a? Array
            items = class_or_item.reject { |e| !e.root? }
          else
            class_or_item = class_or_item.roots if class_or_item.is_a?(Class)
            items = Array(class_or_item)
          end
          result = []
          children = []
          items.each do |root|
            root.class.associate_parents(root.self_and_descendants).map do |i|
              if mover.nil? || mover.new_record? || mover.move_possible?(i)
                if !i.leaf?
                  children.sort_by! &order
                  children.each { |c| result << [yield(c), c.id] }
                  children = []
                  result << [yield(i), i.id]
                else
                  children << i
                 end
              end   
            end.compact
          end
          children.sort_by! &order
          children.each { |c| result << [yield(c), c.id] }
          result
        end
      end
    end
  end
end
