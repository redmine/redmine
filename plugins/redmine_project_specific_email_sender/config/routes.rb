scope '/projects/:project_id', :as => 'project' do
  resource :project_email, :as => 'outbound_email', :only => [:update, :destroy] do
    put 'watchers'
  end
end
