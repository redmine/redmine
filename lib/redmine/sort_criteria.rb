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
  class SortCriteria < Array
    def initialize(arg=nil)
      super()
      if arg.is_a?(Array)
        replace arg
      elsif arg.is_a?(String)
        replace arg.split(',').collect {|s| s.split(':')[0..1]}
      elsif arg.respond_to?(:values)
        replace arg.values
      elsif arg
        raise ArgumentError.new("SortCriteria#new takes an Array, String or Hash, not a #{arg.class.name}.")
      end
      normalize!
    end

    def to_param
      self.collect {|k, o| k + (o == 'desc' ? ':desc' : '')}.join(',')
    end

    def to_a
      Array.new(self)
    end

    def add!(key, asc)
      key = key.to_s
      delete_if {|k, o| k == key}
      prepend([key, asc])
      normalize!
    end

    def add(*args)
      self.class.new(self).add!(*args)
    end

    def first_key
      first.try(:first)
    end

    def first_asc?
      first.try(:last) == 'asc'
    end

    def key_at(arg)
      self[arg].try(:first)
    end

    def order_at(arg)
      self[arg].try(:last)
    end

    def order_for(key)
      detect {|k, order| key.to_s == k}.try(:last)
    end

    def sort_clause(sortable_columns)
      if sortable_columns.is_a?(Array)
        sortable_columns = sortable_columns.inject({}) {|h, k| h[k]=k; h}
      end

      sql = self.collect do |k, o|
        if s = sortable_columns[k]
          s = [s] unless s.is_a?(Array)
          s.collect {|c| append_order(c, o)}
        end
      end.flatten.compact
      sql.blank? ? nil : sql
    end

    private

    def normalize!
      self.reject! {|s| s.first.blank?}
      self.uniq! {|s| s.first}
      self.collect! {|s| s = Array(s); [s.first, (s.last == false || s.last.to_s == 'desc') ? 'desc' : 'asc']}
      self.replace self.first(3)
    end

    # Appends ASC/DESC to the sort criterion unless it has a fixed order
    def append_order(criterion, order)
      if / (asc|desc)$/i.match?(criterion)
        criterion
      else
        Arel.sql "#{criterion} #{order.to_s.upcase}"
      end
    end
  end
end
