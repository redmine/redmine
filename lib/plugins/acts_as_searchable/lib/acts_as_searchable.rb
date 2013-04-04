# Redmine - project management software
# Copyright (C) 2006-2013  Jean-Philippe Lang
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
    module Searchable
      def self.included(base)
        base.extend ClassMethods
      end

      module ClassMethods
        # Options:
        # * :columns - a column or an array of columns to search
        # * :project_key - project foreign key (default to project_id)
        # * :date_column - name of the datetime column (default to created_on)
        # * :sort_order - name of the column used to sort results (default to :date_column or created_on)
        # * :permission - permission required to search the model (default to :view_"objects")
        def acts_as_searchable(options = {})
          return if self.included_modules.include?(Redmine::Acts::Searchable::InstanceMethods)

          cattr_accessor :searchable_options
          self.searchable_options = options

          if searchable_options[:columns].nil?
            raise 'No searchable column defined.'
          elsif !searchable_options[:columns].is_a?(Array)
            searchable_options[:columns] = [] << searchable_options[:columns]
          end

          searchable_options[:project_key] ||= "#{table_name}.project_id"
          searchable_options[:date_column] ||= "#{table_name}.created_on"
          searchable_options[:order_column] ||= searchable_options[:date_column]

          # Should we search custom fields on this model ?
          searchable_options[:search_custom_fields] = !reflect_on_association(:custom_values).nil?

          send :include, Redmine::Acts::Searchable::InstanceMethods
        end
      end

      module InstanceMethods
        def self.included(base)
          base.extend ClassMethods
        end

        module ClassMethods
          # Searches the model for the given tokens
          # projects argument can be either nil (will search all projects), a project or an array of projects
          # Returns the results and the results count
          def search(tokens, projects=nil, options={})
            if projects.is_a?(Array) && projects.empty?
              # no results
              return [[], 0]
            end

            # TODO: make user an argument
            user = User.current
            tokens = [] << tokens unless tokens.is_a?(Array)
            projects = [] << projects unless projects.nil? || projects.is_a?(Array)

            limit_options = {}
            limit_options[:limit] = options[:limit] if options[:limit]

            columns = searchable_options[:columns]
            columns = columns[0..0] if options[:titles_only]

            token_clauses = columns.collect {|column| "(LOWER(#{column}) LIKE ?)"}

            if !options[:titles_only] && searchable_options[:search_custom_fields]
              searchable_custom_field_ids = CustomField.where(:type => "#{self.name}CustomField", :searchable => true).pluck(:id)
              if searchable_custom_field_ids.any?
                custom_field_sql = "#{table_name}.id IN (SELECT customized_id FROM #{CustomValue.table_name}" +
                  " WHERE customized_type='#{self.name}' AND customized_id=#{table_name}.id AND LOWER(value) LIKE ?" +
                  " AND #{CustomValue.table_name}.custom_field_id IN (#{searchable_custom_field_ids.join(',')}))"
                token_clauses << custom_field_sql
              end
            end

            sql = (['(' + token_clauses.join(' OR ') + ')'] * tokens.size).join(options[:all_words] ? ' AND ' : ' OR ')

            tokens_conditions = [sql, * (tokens.collect {|w| "%#{w.downcase}%"} * token_clauses.size).sort]

            scope = self.scoped
            project_conditions = []
            if searchable_options.has_key?(:permission)
              project_conditions << Project.allowed_to_condition(user, searchable_options[:permission] || :view_project)
            elsif respond_to?(:visible)
              scope = scope.visible(user)
            else
              ActiveSupport::Deprecation.warn "acts_as_searchable with implicit :permission option is deprecated. Add a visible scope to the #{self.name} model or use explicit :permission option."
              project_conditions << Project.allowed_to_condition(user, "view_#{self.name.underscore.pluralize}".to_sym)
            end
            # TODO: use visible scope options instead
            project_conditions << "#{searchable_options[:project_key]} IN (#{projects.collect(&:id).join(',')})" unless projects.nil?
            project_conditions = project_conditions.empty? ? nil : project_conditions.join(' AND ')

            results = []
            results_count = 0

            scope = scope.
              includes(searchable_options[:include]).
              order("#{searchable_options[:order_column]} " + (options[:before] ? 'DESC' : 'ASC')).
              where(project_conditions).
              where(tokens_conditions)

            results_count = scope.count

            scope_with_limit = scope.limit(options[:limit])
            if options[:offset]
              scope_with_limit = scope_with_limit.where("#{searchable_options[:date_column]} #{options[:before] ? '<' : '>'} ?", options[:offset])
            end
            results = scope_with_limit.all

            [results, results_count]
          end
        end
      end
    end
  end
end
