class Repository::Subversion < Repository
  generator_for :type, :method => 'Subversion'
  generator_for :url, :start => 'file:///test/svn'

end
