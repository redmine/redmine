# frozen_string_literal: true

require_relative 'lib/acts_as_searchable'
ActiveRecord::Base.send(:include, Redmine::Acts::Searchable)
