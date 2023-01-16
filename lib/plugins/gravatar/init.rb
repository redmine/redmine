# frozen_string_literal: true

require_relative 'lib/gravatar'
ActionView::Base.send :include, GravatarHelper::PublicMethods
