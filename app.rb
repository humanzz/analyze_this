require 'rubygems'
require 'haml'
require 'sinatra'
require 'json'
require 'timeout'

#lib
$:.unshift File.join(File.dirname(__FILE__),'lib')
require 'html_page_data'


get "/" do
  content_type 'text/html', :charset => 'utf-8'
  if params[:url]
    p = HTMLPageData.get(params[:url])
    haml :index, :locals =>{:p => p, :url => params[:url]}
  else
    haml :index, :locals => {:url => ""}
  end
end

get "/js" do
  if params[:url]
      p = HTMLPageData.get(params[:url], browser_headers)
      json = {:error => false, :title => p.title, :description => p.description,
       :keywords => p.keywords, :host => p.host, :favicon => p.favicon}.to_json
  else
    json = {:error => true, :message => "Care to provide a url?"}.to_json
  end
  wrap_response json
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

use_in_file_templates!

__END__

@@ layout
!!! 1.1
%html
  %head
    %title Analyze This!
    %link{:rel => 'stylesheet', :href => 'http://www.w3.org/StyleSheets/Core/Modernist', :type => 'text/css'}  
  = yield
  
@@ index
%form{:method=>'get'}
  %h1.title Analyze This!
  %input{:type=>'text', :name=>'url', :value => url}
  %input{:type=>'submit', :value=>'submit'}

- if p  
  %h2
    %img{:src=>p.favicon}
    =p.title
  %h3= p.description
  %h4= p.keywords.join(", ")
