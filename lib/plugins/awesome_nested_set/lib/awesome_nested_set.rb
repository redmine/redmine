# FIXME : Not sure if still "compatibility" in Awesome Nested Set
# Threadsafe include addition (will leave commented for now)
# require 'awesome_nested_set/compatability'

require 'awesome_nested_set/awesome_nested_set'
require 'active_record'
ActiveRecord::Base.send :extend, CollectiveIdea::Acts::NestedSet

if defined?(ActionView)
  require 'awesome_nested_set/helper'
  ActionView::Base.send :include, CollectiveIdea::Acts::NestedSet::Helper
end
