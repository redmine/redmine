class Change < ActiveRecord::Base
  generator_for :action => 'A'
  generator_for :path, :start => 'test/dir/aaa0001'
  generator_for :changeset, :method => :generate_changeset

  def self.generate_changeset
    Changeset.generate!
  end
end
