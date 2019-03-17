# frozen_string_literal: true

require 'gravatar'
ActionView::Base.send :include, GravatarHelper::PublicMethods
