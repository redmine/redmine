# frozen_string_literal: true

require_relative 'lib/gravatar'
Rails.application.reloader.to_prepare do
  ApplicationRecord.send :include, GravatarHelper::PublicMethods
end
