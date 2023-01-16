# frozen_string_literal: true

require_relative 'lib/acts_as_activity_provider'
ActiveRecord::Base.send(:include, Redmine::Acts::ActivityProvider)
