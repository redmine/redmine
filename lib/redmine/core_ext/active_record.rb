# Redmine - project management software
# Copyright (C) 2006-2011  Jean-Philippe Lang
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

module ActiveRecord
  class Base
    def self.find_ids(options={})
      find_ids_with_associations(options)
    end
  end

  module Associations
    module ClassMethods
      def find_ids_with_associations(options = {})
        catch :invalid_query do
          join_dependency = ActiveRecord::Associations::ClassMethods::JoinDependency.new(self, merge_includes(scope(:find, :include), options[:include]), options[:joins])
          return connection.select_values(construct_ids_finder_sql_with_included_associations(options, join_dependency))
        end
        []
      end

      def construct_ids_finder_sql_with_included_associations(options, join_dependency)
        scope = scope(:find)
        sql = "SELECT #{table_name}.id FROM #{(scope && scope[:from]) || options[:from] || quoted_table_name} "
        sql << join_dependency.join_associations.collect{|join| join.association_join }.join

        add_joins!(sql, options[:joins], scope)
        add_conditions!(sql, options[:conditions], scope)
        add_limited_ids_condition!(sql, options, join_dependency) if !using_limitable_reflections?(join_dependency.reflections) && ((scope && scope[:limit]) || options[:limit])

        add_group!(sql, options[:group], options[:having], scope)
        add_order!(sql, options[:order], scope)
        add_limit!(sql, options, scope) if using_limitable_reflections?(join_dependency.reflections)
        add_lock!(sql, options, scope)

        return sanitize_sql(sql)
      end
    end
  end
end
