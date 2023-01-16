# frozen_string_literal: true

require_relative 'lib/active_record/acts/tree'
ActiveRecord::Base.send :include, ActiveRecord::Acts::Tree
