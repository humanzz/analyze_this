require 'sinatra'

app_root = File.join(File.expand_path(File.dirname(__FILE__)),'..')
Sinatra::Application.set :environment, :production
Sinatra::Application.set :run, false
Sinatra::Application.set :public, File.join(app_root,'public')

#log = File.new("sinatra.log", "w")
#STDOUT.reopen(log)
#STDERR.reopen(log)

require File.join(app_root,'app.rb')
run Sinatra::application