class Repository < ActiveRecord::Base
  generator_for :type => 'Subversion'
  generator_for :url, :start => 'file:///test/svn'

end
