Redmine::Plugin.register :github_relation do
  name 'Github Relation plugin'
  author 'Author name'
  description 'This is a plugin for Redmine'
  version '0.0.1'
  url 'http://example.com/path/to/plugin'
  author_url 'http://example.com/about'

  project_module :github_project do
    permission :manage_github_relation, :github_project => [:new, :edit, :create, :update]
    permission :show_github_relation, :github_project => [:index, :show]
    permission :get_from_github, :github_project => [:get_data]
  end
  menu :project_menu, :github_project, {controller: :github_project, action: :index}, :caption => 'github_relation', :after => :activity, :param => :project_id
end
