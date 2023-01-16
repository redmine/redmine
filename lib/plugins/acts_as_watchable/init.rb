# frozen_string_literal: true

# Include hook code here
require_relative 'lib/acts_as_watchable'
ActiveRecord::Base.send(:include, Redmine::Acts::Watchable)
