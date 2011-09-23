class CustomField < ActiveRecord::Base
  generator_for :name, :start => 'CustomField0'
  generator_for :field_format => 'string'

end
