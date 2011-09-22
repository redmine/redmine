class WikiRedirect < ActiveRecord::Base
  generator_for :title, :start => 'AWikiPage'
  generator_for :redirects_to, :start => '/a/path/000001'
  generator_for :wiki, :method => :generate_wiki

  def self.generate_wiki
    Wiki.generate!
  end
end
