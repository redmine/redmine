# frozen_string_literal: true

require_relative 'lib/acts_as_attachable'
ActiveRecord::Base.send(:include, Redmine::Acts::Attachable)
