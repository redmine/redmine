# Redmine - project management software
# Copyright (C) 2006-2017  Jean-Philippe Lang
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
  module Search

    mattr_accessor :available_search_types
    @@available_search_types = []

    class << self
      def map(&block)
        yield self
      end

      # Registers a search provider
      def register(search_type, options={})
        search_type = search_type.to_s
        @@available_search_types << search_type unless @@available_search_types.include?(search_type)
      end

      # Returns the cache store for search results
      # Can be configured with config.redmine_search_cache_store= in config/application.rb
      def cache_store
        @@cache_store ||= begin
          # if config.search_cache_store was not previously set, a no method error would be raised
          config = Rails.application.config.redmine_search_cache_store rescue :memory_store
          if config
            ActiveSupport::Cache.lookup_store config
          end
        end
      end
    end

    class Fetcher
      attr_reader :tokens

      def initialize(question, user, scope, projects, options={})
        @user = user
        @question = question.strip
        @scope = scope
        @projects = projects
        @cache = options.delete(:cache)
        @options = options

        # extract tokens from the question
        # eg. hello "bye bye" => ["hello", "bye bye"]
        @tokens = @question.scan(%r{((\s|^)"[^"]+"(\s|$)|\S+)}).collect {|m| m.first.gsub(%r{(^\s*"\s*|\s*"\s*$)}, '')}
        # tokens must be at least 2 characters long
        # but for Chinese characters (汉字/漢字), tokens can be one character
        @tokens = @tokens.uniq.select {|w| w.length > 1 || w =~ /\p{Han}/ }
        # no more than 5 tokens to search for
        @tokens.slice! 5..-1
      end

      # Returns the total result count
      def result_count
        result_ids.size
      end

      # Returns the result count by type
      def result_count_by_type
        ret = Hash.new {|h,k| h[k] = 0}
        result_ids.group_by(&:first).each do |scope, ids|
          ret[scope] += ids.size
        end
        ret
      end

      # Returns the results for the given offset and limit
      def results(offset, limit)
        result_ids_to_load = result_ids[offset, limit] || []
        results_by_scope = Hash.new {|h,k| h[k] = []}
        result_ids_to_load.group_by(&:first).each do |scope, scope_and_ids|
          klass = scope.singularize.camelcase.constantize
          results_by_scope[scope] += klass.search_results_from_ids(scope_and_ids.map(&:last))
        end
        result_ids_to_load.map do |scope, id|
          results_by_scope[scope].detect {|record| record.id == id}
        end.compact
      end

      # Returns the results ids, sorted by rank
      def result_ids
        @ranks_and_ids ||= load_result_ids_from_cache
      end

      private

      def project_ids
        Array.wrap(@projects).map(&:id)
      end

      def load_result_ids_from_cache
        if Redmine::Search.cache_store
          cache_key = ActiveSupport::Cache.expand_cache_key(
            [@question, @user.id, @scope.sort, @options, project_ids.sort]
          )
          Redmine::Search.cache_store.fetch(cache_key, :force => !@cache) do
            load_result_ids
          end
        else
          load_result_ids
        end
      end

      def load_result_ids
        ret = []
        # get all the results ranks and ids
        @scope.each do |scope|
          klass = scope.singularize.camelcase.constantize
          ranks_and_ids_in_scope = klass.search_result_ranks_and_ids(@tokens, User.current, @projects, @options)
          ret += ranks_and_ids_in_scope.map {|rs| [scope, rs]}
        end
        # sort results, higher rank and id first
        ret.sort! {|a,b| b.last <=> a.last}
        # only keep ids now that results are sorted
        ret.map! {|scope, r| [scope, r.last]}
        ret
      end
    end

    module Controller
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        @@default_search_scopes = Hash.new {|hash, key| hash[key] = {:default => nil, :actions => {}}}
        mattr_accessor :default_search_scopes

        # Set the default search scope for a controller or specific actions
        # Examples:
        #   * search_scope :issues # => sets the search scope to :issues for the whole controller
        #   * search_scope :issues, :only => :index
        #   * search_scope :issues, :only => [:index, :show]
        def default_search_scope(id, options = {})
          if actions = options[:only]
            actions = [] << actions unless actions.is_a?(Array)
            actions.each {|a| default_search_scopes[controller_name.to_sym][:actions][a.to_sym] = id.to_s}
          else
            default_search_scopes[controller_name.to_sym][:default] = id.to_s
          end
        end
      end

      def default_search_scopes
        self.class.default_search_scopes
      end

      # Returns the default search scope according to the current action
      def default_search_scope
        @default_search_scope ||= default_search_scopes[controller_name.to_sym][:actions][action_name.to_sym] ||
                                  default_search_scopes[controller_name.to_sym][:default]
      end
    end
  end
end
