class Changeset < ActiveRecord::Base
  generator_for :revision, :start => '1'
  generator_for :committed_on => Date.today
  generator_for :repository, :method => :generate_repository

  def self.generate_repository
    Repository::Subversion.generate!
  end
end
