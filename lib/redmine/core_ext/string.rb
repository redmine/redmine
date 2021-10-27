# frozen_string_literal: true

require File.dirname(__FILE__) + '/string/conversions'
require File.dirname(__FILE__) + '/string/inflections'

# @private
class String
  include Redmine::CoreExt::String::Conversions
  include Redmine::CoreExt::String::Inflections
end
