# frozen_string_literal: true

require_relative 'string/conversions'
require_relative 'string/inflections'

# @private
class String
  include Redmine::CoreExt::String::Conversions
  include Redmine::CoreExt::String::Inflections
end
