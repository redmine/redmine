# Redmine - project management software
# Copyright (C) 2006-2014  Jean-Philippe Lang
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
        # Adds the search methods to the class.
        #
        # Options:
        # * :columns - a column or an array of columns to search
        # * :project_key - project foreign key (default to project_id)
        # * :date_column - name of the datetime column used to sort results (default to :created_on)
        # * :permission - permission required to search the model
        # * :scope - scope used to search results
        # * :preload - associations to preload when loading results for display
        def acts_as_searchable(options = {})
          return if self.included_modules.include?(Redmine::Acts::Searchable::InstanceMethods)
          options.assert_valid_keys(:columns, :project_key, :date_column, :permission, :scope, :preload)

          cattr_accessor :searchable_options
          self.searchable_options = options

          if searchable_options[:columns].nil?
            raise 'No searchable column defined.'
          elsif !searchable_options[:columns].is_a?(Array)
            searchable_options[:columns] = [] << searchable_options[:columns]
          end

          searchable_options[:project_key] ||= "#{table_name}.project_id"
          searchable_options[:date_column] ||= :created_on

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
          # Searches the model for the given tokens and user visibility.
          # The projects argument can be either nil (will search all projects), a project or an array of projects.
          # Returns an array that contains the rank and id of all results.
          # In current implementation, the rank is the record timestamp.
          #
          # Valid options:
          # * :titles_only - searches tokens in the first searchable column only
          # * :all_words - searches results that match all token
          # * :limit - maximum number of results to return
          #
          # Example:
          #   Issue.search_result_ranks_and_ids("foo")
          #   # => [[Tue, 26 Jun 2007 22:16:00 UTC +00:00, 69], [Mon, 08 Oct 2007 14:31:00 UTC +00:00, 123]]
          def search_result_ranks_and_ids(tokens, user=User.current, projects=nil, options={})
            if projects.is_a?(Array) && projects.empty?
              # no results
              return []
            end

            tokens = [] << tokens unless tokens.is_a?(Array)
            projects = [] << projects if projects.is_a?(Project)

            columns = searchable_options[:columns]
            columns = columns[0..0] if options[:titles_only]

            token_clauses = columns.collect {|column| "(#{search_token_match_statement(column)})"}

            if !options[:titles_only] && searchable_options[:search_custom_fields]
              searchable_custom_fields = CustomField.where(:type => "#{self.name}CustomField", :searchable => true)
              fields_by_visibility = searchable_custom_fields.group_by {|field|
                field.visibility_by_project_condition(searchable_options[:project_key], user, "cfs.custom_field_id")
              }
              # only 1 subquery for all custom fields with the same visibility statement
              fields_by_visibility.each do |visibility, fields|
                ids = fields.map(&:id).join(',')
                sql = "#{table_name}.id IN (SELECT cfs.customized_id FROM #{CustomValue.table_name} cfs" +
                  " WHERE cfs.customized_type='#{self.name}' AND cfs.customized_id=#{table_name}.id" +
                  " AND cfs.custom_field_id IN (#{ids})" +
                  " AND #{search_token_match_statement('cfs.value')}" +
                  " AND #{visibility})"
                token_clauses << sql
              end
            end

            sql = (['(' + token_clauses.join(' OR ') + ')'] * tokens.size).join(options[:all_words] ? ' AND ' : ' OR ')

            tokens_conditions = [sql, * (tokens.collect {|w| "%#{w}%"} * token_clauses.size).sort]

            search_scope(user, projects).
              reorder(searchable_options[:date_column] => :desc, :id => :desc).
              where(tokens_conditions).
              limit(options[:limit]).
              uniq.
              pluck(searchable_options[:date_column], :id)
          end

          def search_token_match_statement(column, value='?')
            case connection.adapter_name
            when /postgresql/i
              "#{column} ILIKE #{value}"
            else
              "#{column} LIKE #{value}"
            end
          end
          private :search_token_match_statement

          # Returns the search scope for user and projects
          def search_scope(user, projects)
            scope = (searchable_options[:scope] || self)
            if scope.is_a? Proc
              scope = scope.call
            end

            if respond_to?(:visible) && !searchable_options.has_key?(:permission)
              scope = scope.visible(user)
            else
              permission = searchable_options[:permission] || :view_project
              scope = scope.where(Project.allowed_to_condition(user, permission))
            end

            if projects
              scope = scope.where("#{searchable_options[:project_key]} IN (?)", projects.map(&:id))
            end
            scope
          end
          private :search_scope

          # Returns search results of given ids
          def search_results_from_ids(ids)
            where(:id => ids).preload(searchable_options[:preload]).to_a
          end

          # Returns search results with same arguments as search_result_ranks_and_ids
          def search_results(*args)
            ranks_and_ids = search_result_ranks_and_ids(*args)
            search_results_from_ids(ranks_and_ids.map(&:last))
          end
        end
      end
    end
  end
end
