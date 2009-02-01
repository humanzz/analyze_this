$:.unshift File.join(File.dirname(__FILE__),'lib')
require 'rubygems'
require 'sinatra'
require 'html_page_data'
require 'json'
require 'timeout'

get "/analyze_this" do
  if params[:url]
    Timeout::timeout(4) do
	  #TODO pass the request headers
      p = HTMLPageData.get(params[:url])
      {:error => false, :title => p.title, :description => p.description,
       :keywords => p.keywords, :host => p.host}.to_json  
    end
  else
    {:error => true, :message => "Care to provide a url?"}.to_json
  end
end

error do
  puts ">>>>>>>>>>#{request.env['sinatra.error']}"
  {:error => true, :message => "There was an error with your request"}.to_json
end