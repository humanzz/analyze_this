require 'sinatra'
 
Sinatra::Application.set :environment, :production
Sinatra::Application.set :run, false

#log = File.new("sinatra.log", "w")
#STDOUT.reopen(log)
#STDERR.reopen(log)

require 'app'
run Sinatra::application
