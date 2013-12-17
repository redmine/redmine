# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html
RedmineApp::Application.routes.draw do
  resources :github_project do
    collection do
      put :get_data
    end
  end
end
