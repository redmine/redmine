RedmineApp::Application.routes.draw do
	scope "/projects/:project_id/knowledgebase" do
		resources :categories, :via => [:get, :post]
		get 'articles/:id/diff/:version/vs/:version_from', :controller => 'articles', :action => 'diff'
		get 'articles/:id/diff/:version', :controller => 'articles', :action => 'diff'
		resources :articles do
			collection do
				get "tagged"
				get "authored"
				post "preview"
			end

			get "comment"

			member do
				patch "preview"
				post "add_comment"
				post "destroy_comment"
				post "rate"
				get  "diff"
				get  "version"
				get  "revert"
			end
		end
	end
end
