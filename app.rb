#requires
require 'rubygems'
require 'sinatra'
require 'json'
require 'timeout'

#neverblock
#require 'neverblock'
#require 'neverblock-io'
#require 'never_block/servers/thin'

#lib
$:.unshift File.join(File.dirname(__FILE__),'lib')
require 'html_page_data'

get "/analyze_this" do
  if params[:url]
    #Timeout::timeout(4) do
      p = HTMLPageData.get(params[:url], browser_headers)
      json = {:error => false, :title => p.title, :description => p.description,
       :keywords => p.keywords, :host => p.host}.to_json  
    #end
  else
    json = {:error => true, :message => "Care to provide a url?"}.to_json
  end
  wrap_response json
end

error do
  #puts ">>>>>>>>>>#{request.env['sinatra.error']}"
  wrap_response({:error => true, :message => "There was an error with your request"}.to_json)
end

def browser_headers
  headers = {}
  ['User-Agent', 'Accept-Language', 'Accept-Charset'].each do |h|
    header_key = "HTTP_#{h.gsub("-","_")}".upcase
    headers[h] = request.env[header_key] if request.env[header_key]
  end
  headers
end

def wrap_response(json)
  response['Content-Type'] = "application/json"
  if params[:callback]
    json = "#{params[:callback]}(#{json})"
    response['Content-Type'] = "application/javascript"
  end
  json
end
