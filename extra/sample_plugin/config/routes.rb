# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html

match 'projects/:id/hello', :to => 'example#say_hello', :via => 'get'
match 'projects/:id/bye', :to => 'example#say_goodbye', :via => 'get'

resources 'meetings'
