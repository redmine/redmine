# frozen_string_literal: true

require_relative 'lib/active_record/acts/tree'
Rails.application.reloader.to_prepare do
  ApplicationRecord.send :include, ActiveRecord::Acts::Tree
end
