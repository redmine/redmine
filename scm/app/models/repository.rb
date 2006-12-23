class Repository < ActiveRecord::Base
  belongs_to :project
  validates_presence_of :url
  validates_format_of :url, :with => /^(http|https|svn):\/\/.+/i
  
  @scm = nil
    
  def scm
    @scm ||= SvnRepos::Base.new url
  end
end
