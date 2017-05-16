class TutorialsController < ApplicationController
  include ApplicationHelper
  
  def index
    @news = News.latest User.current
    @projects = Project.latest User.current
    userscope = User.logged.status(@status)
    @allusers = userscope.find(:all)
  end
  
end
