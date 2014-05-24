require 'awesome_nested_set/awesome_nested_set'
require 'active_record'
ActiveRecord::Base.send :extend, CollectiveIdea::Acts::NestedSet

if defined?(ActionView)
  require 'awesome_nested_set/helper'
  ActionView::Base.send :include, CollectiveIdea::Acts::NestedSet::Helper
end
