# frozen_string_literal: true

require_relative 'lib/acts_as_event'
ActiveRecord::Base.send(:include, Redmine::Acts::Event)
