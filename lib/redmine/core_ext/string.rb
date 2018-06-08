require File.dirname(__FILE__) + '/string/conversions'
require File.dirname(__FILE__) + '/string/inflections'

# @private
class String
  include Redmine::CoreExtensions::String::Conversions
  include Redmine::CoreExtensions::String::Inflections
end
