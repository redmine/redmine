# frozen_string_literal: true

require File.dirname(__FILE__) + '/lib/gravatar'
ActionView::Base.send :include, GravatarHelper::PublicMethods
