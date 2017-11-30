#userstory.rb
#ENSE 374 Project
#Nicolas Achter - 200361157 - Author
#Nickolas Schmidt - 200354159
#Nikolas Lendvoy - 200234841
#Shayan Khan - 200361210

require 'erb'
require 'sinatra'

get '/US/' do
	erb :userstory
end

post '/US/' do
    user = params[:user]
    want = params[:want]
		action = params[:action]

    erb :userstory_index, :locals => {'user' => user, 'want' => want, 'action' => action}
end

#defines Userstory class
class Userstory
	#constructor
	def initialize(user, want, action)
		@user = user
		@want = want
		@action = action
	end

	#prints the userstory
	def print
		ustory = "As a #{@user} I want to do/have #{@want} so I can #{@action}"
		return ustory
	end
end
