# frozen_string_literal: true

require_relative 'lib/acts_as_customizable'
ActiveRecord::Base.send(:include, Redmine::Acts::Customizable)
