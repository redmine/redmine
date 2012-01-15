class Repository < ActiveRecord::Base
  generator_for :type => 'Subversion'
  generator_for :url, :start => 'file:///test/svn'
  generator_for :identifier, :start => 'repo1'
end
