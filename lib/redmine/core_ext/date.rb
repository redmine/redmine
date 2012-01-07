require File.dirname(__FILE__) + '/date/calculations'

class Date #:nodoc:
  include Redmine::CoreExtensions::Date::Calculations
end
