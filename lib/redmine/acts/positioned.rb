# Redmine - project management software
# Copyright (C) 2006-2016  Jean-Philippe Lang
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
  module Acts
    module Positioned
      def self.included(base)
        base.extend ClassMethods
      end

      # This extension provides the capabilities for reordering objects in a list.
      # The class needs to have a +position+ column defined as an integer on the
      # mapped database table.
      module ClassMethods
        # Configuration options are:
        #
        # * +scope+ - restricts what is to be considered a list. Must be a symbol
        # or an array of symbols
        def acts_as_positioned(options = {})
          class_attribute :positioned_options
          self.positioned_options = {:scope => Array(options[:scope])}

          send :include, Redmine::Acts::Positioned::InstanceMethods

          before_save :set_default_position
          after_save :update_position
          after_destroy :remove_position
        end
      end

      module InstanceMethods
        def self.included(base)
          base.extend ClassMethods
        end

        private

        def position_scope
          build_position_scope {|c| send(c)}
        end

        def position_scope_was
          build_position_scope {|c| send("#{c}_was")}
        end

        def build_position_scope
          condition_hash = self.class.positioned_options[:scope].inject({}) do |h, column|
            h[column] = yield(column)
            h
          end
          self.class.where(condition_hash)
        end

        def set_default_position
          if position.nil?
            self.position = position_scope.maximum(:position).to_i + (new_record? ? 1 : 0)
          end
        end

        def update_position
          if !new_record? && position_scope_changed?
            remove_position
            insert_position
          elsif position_changed?
            if position_was.nil?
              insert_position
            else
              shift_positions
            end
          end
        end

        def insert_position
          position_scope.where("position >= ? AND id <> ?", position, id).update_all("position = position + 1")
        end

        def remove_position
          position_scope_was.where("position >= ? AND id <> ?", position_was, id).update_all("position = position - 1")
        end

        def position_scope_changed?
          (changed & self.class.positioned_options[:scope].map(&:to_s)).any?
        end

        def shift_positions
          offset = position_was <=> position
          min, max = [position, position_was].sort
          r = position_scope.where("id <> ? AND position BETWEEN ? AND ?", id, min, max).update_all("position = position + #{offset}")
          if r != max - min
            reset_positions_in_list
          end
        end

        def reset_positions_in_list
          position_scope.reorder(:position, :id).pluck(:id).each_with_index do |record_id, p|
            self.class.where(:id => record_id).update_all(:position => p+1)
          end
        end
      end
    end
  end
end

ActiveRecord::Base.send :include, Redmine::Acts::Positioned
