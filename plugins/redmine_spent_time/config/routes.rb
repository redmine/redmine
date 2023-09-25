# -*- encoding : utf-8 -*-
get 'spent_time', to: 'spent_time#index'
get 'spent_time/destroy_entry', to: 'spent_time#destroy_entry'
post 'spent_time/update_project_issues', to: 'spent_time#update_project_issues'
post 'spent_time/create_entry', to: 'spent_time#create_entry'
post 'spent_time/report', to: 'spent_time#report'
