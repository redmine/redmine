class Enumeration < ActiveRecord::Base
  generator_for :name, :start => 'Enumeration0'
  generator_for :type => 'TimeEntryActivity'

end
