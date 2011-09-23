class Version < ActiveRecord::Base
  generator_for :name, :start => 'Version 1.0.0'
  generator_for :status => 'open'

end
