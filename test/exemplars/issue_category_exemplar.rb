class IssueCategory < ActiveRecord::Base
  generator_for :name, :start => 'Category 0001'

end
