require File.dirname(__FILE__) + '/../test_helper'

class ArticlesControllerTest < ActionController::TestCase
  fixtures :projects, :roles, :users
  plugin_fixtures :kb_articles, :enabled_modules

  def setup
    User.current = User.find(1)
    @request.session[:user_id] = 1
    @project = Project.find(1)
  end

  def test_index
    Role.find(1).add_permission! :view_kb_articles
    get :index, :project_id => @project.id

    assert_response :success
    assert_template 'index'
  end

end
