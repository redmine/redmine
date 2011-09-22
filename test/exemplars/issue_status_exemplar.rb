class IssueStatus < ActiveRecord::Base
  generator_for :name, :start => 'Status 0'

end
