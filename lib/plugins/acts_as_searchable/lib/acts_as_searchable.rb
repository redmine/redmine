# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2019  Jean-Philippe Lang
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

require 'redmine/database'

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

          # Should we search additional associations on this model ?
          searchable_options[:search_custom_fields] = reflect_on_association(:custom_values).present?
          searchable_options[:search_attachments] = reflect_on_association(:attachments).present?
          searchable_options[:search_journals] = reflect_on_association(:journals).present?

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
          # In current implementation, the rank is the record timestamp converted as an integer.
          #
          # Valid options:
          # * :titles_only - searches tokens in the first searchable column only
          # * :all_words - searches results that match all token
          # * :
          # * :limit - maximum number of results to return
          #
          # Example:
          #   Issue.search_result_ranks_and_ids("foo")
          #   # => [[1419595329, 69], [1419595622, 123]]
          def search_result_ranks_and_ids(tokens, user=User.current, projects=nil, options={})
            tokens = [] << tokens unless tokens.is_a?(Array)
            projects = [] << projects if projects.is_a?(Project)

            columns = searchable_options[:columns]
            columns = columns[0..0] if options[:titles_only]

            r = []
            queries = 0

            unless options[:attachments] == 'only'
              r = fetch_ranks_and_ids(
                search_scope(user, projects, options).
                where(search_tokens_condition(columns, tokens, options[:all_words])),
                options[:limit]
              )
              queries += 1
              if !options[:titles_only] && searchable_options[:search_custom_fields]
                searchable_custom_fields = CustomField.where(:type => "#{self.name}CustomField", :searchable => true).to_a
                if searchable_custom_fields.any?
                  fields_by_visibility = searchable_custom_fields.group_by {|field|
                    field.visibility_by_project_condition(searchable_options[:project_key], user, "#{CustomValue.table_name}.custom_field_id")
                  }
                  clauses = []
                  fields_by_visibility.each do |visibility, fields|
                    clauses << "(#{CustomValue.table_name}.custom_field_id IN (#{fields.map(&:id).join(',')}) AND (#{visibility}))"
                  end
                  visibility = clauses.join(' OR ')
                  r |= fetch_ranks_and_ids(
                    search_scope(user, projects, options).
                    joins(:custom_values).
                    where(visibility).
                    where(search_tokens_condition(["#{CustomValue.table_name}.value"], tokens, options[:all_words])),
                    options[:limit]
                  )
                  queries += 1
                end
              end

              if !options[:titles_only] && searchable_options[:search_journals]
                r |= fetch_ranks_and_ids(
                  search_scope(user, projects, options).
                  joins(:journals).
                  where("#{Journal.table_name}.private_notes = ? OR (#{Project.allowed_to_condition(user, :view_private_notes)})", false).
                  where(search_tokens_condition(["#{Journal.table_name}.notes"], tokens, options[:all_words])),
                  options[:limit]
                )
                queries += 1
              end
            end

            if searchable_options[:search_attachments] && (options[:titles_only] ? options[:attachments] == 'only' : options[:attachments] != '0')
              r |= fetch_ranks_and_ids(
                search_scope(user, projects, options).
                joins(:attachments).
                where(search_tokens_condition(["#{Attachment.table_name}.filename", "#{Attachment.table_name}.description"], tokens, options[:all_words])),
                options[:limit]
              )
              queries += 1
            end

            if queries > 1
              r = r.sort.reverse
              if options[:limit] && r.size > options[:limit]
                r = r[0, options[:limit]]
              end
            end

            r
          end

          def search_tokens_condition(columns, tokens, all_words)
            token_clauses = columns.map {|column| "(#{search_token_match_statement(column)})"}
            sql = (['(' + token_clauses.join(' OR ') + ')'] * tokens.size).join(all_words ? ' AND ' : ' OR ')
            [sql, * (tokens.collect {|w| "%#{w}%"} * token_clauses.size).sort]
          end
          private :search_tokens_condition

          def search_token_match_statement(column, value='?')
            Redmine::Database.like(column, value)
          end
          private :search_token_match_statement

          def fetch_ranks_and_ids(scope, limit)
            scope.
              reorder(searchable_options[:date_column] => :desc, :id => :desc).
              limit(limit).
              distinct.
              pluck(searchable_options[:date_column], :id).
              # converts timestamps to integers for faster sort
              map {|timestamp, id| [timestamp.to_i, id]}
          end
          private :fetch_ranks_and_ids

          # Returns the search scope for user and projects
          def search_scope(user, projects, options={})
            if projects.is_a?(Array) && projects.empty?
              # no results
              return none
            end

            scope = (searchable_options[:scope] || self)
            if scope.is_a? Proc
              scope = scope.call(options)
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
