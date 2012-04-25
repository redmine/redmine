require File.dirname(__FILE__) + '/string/conversions'
require File.dirname(__FILE__) + '/string/inflections'

class String #:nodoc:
  include Redmine::CoreExtensions::String::Conversions
  include Redmine::CoreExtensions::String::Inflections

  def is_binary_data?
    ( self.count( "^ -~", "^\r\n" ).fdiv(self.size) > 0.3 || self.index( "\x00" ) ) unless empty?
  end
end
