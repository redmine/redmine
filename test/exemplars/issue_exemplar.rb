class Issue < ActiveRecord::Base
  generator_for :subject, :start => 'Subject 0'
  generator_for :author, :method => :next_author
  generator_for :priority, :method => :fetch_priority

  def self.next_author
    User.generate_with_protected!
  end

  def self.fetch_priority
    IssuePriority.first || IssuePriority.generate!
  end
end
