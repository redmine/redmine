# frozen_string_literal: false

require 'gravatar'
ActionView::Base.send :include, GravatarHelper::PublicMethods
