RedmineApp::Application.routes.draw do
  match 'bitbucket_hook' => 'bitbucket_hook#index', :via => [:post]
end
