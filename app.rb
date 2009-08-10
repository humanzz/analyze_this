require 'rubygems'
require 'sinatra'
require 'json'

#lib
$:.unshift File.join(File.dirname(__FILE__),'lib')
require 'html_page_data'

set :public, 'public'

before do
  # Set proper content type
  if request.path == "/js"
    if params[:callback]
      content_type 'application/javascript', :charset => 'utf-8'
    else
      content_type 'application/json', :charset => 'utf-8'
    end
  else
    content_type 'text/html', :charset => 'utf-8'
  end
end

get "/" do
  if params[:url]
    p = get_page(params)
    erb :show, :locals =>{:p => p, :url => params[:url], :error => false}
  else
    erb :show, :locals => {:url => "", :error => false}
  end
end

get "/js" do
  p = get_page(params)
  json = {:error => false, :title => p.title, :description => p.description,
          :keywords => p.keywords, :host => p.host, :favicon => p.favicon,
          :images => p.image_sources}.to_json
  wrap_response json
end

error(Timeout::Error) {render_error("The request is taking too long!")}
error(URI::InvalidURIError) {render_error("The URL provided is invalid!")}
error {render_error("An error has occured!")}

def render_error(message)
  if request.path == "/js"
    wrap_response({:error => true, :message =>message}.to_json)
  else
    erb :show, :locals =>{:url => params[:url], :error => true, :message => message}
  end
end

def get_page(params)
  require 'neverblock/core/system/timeout' unless defined? Timeout
  Timeout::timeout(5) do
    p = HTMLPageData.get(params[:url])
    #p = HTMLPageData.get(params[:url], browser_headers)
    return p
  end
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
  json = "#{params[:callback]}(#{json})" if params[:callback]
  json
end
