require 'blank_helper'
require 'net/http'
require 'cgi'
require 'http_encoding_helper'
require 'nokogiri'

class HTMLPageData

  def self.get(url, headers = {})
    p = self.new(url, headers)
    p.response
    p
  end  
  
  def initialize(url,headers = {})
    @url = URI.parse(url)
    @url = URI.parse "http://#{url}" if @url.scheme.nil?	
    raise ArgumentError, 'The url has to be absolute' unless @url.absolute?
    init_headers(headers)
  end
  
  def host
    @url.host
  end
  
  def title
    if @title.nil? && document
      document.css("title", "meta[name=title]").each {|n| @title = n.get_attribute("content").nil? ? clean_html(n.inner_html) : clean_html(n.get_attribute("content"))}
    end
    @title||=""
  end
  
  def keywords
    if @keywords.nil? && document
      document.css("meta[name=keywords]").each {|n| @keywords = n.get_attribute("content").blank? ? [] : n.get_attribute("content").split(",").collect {|k|k.strip}}
    end
    @keywords||=[]
  end
  
  def description
    if @description.nil? && document
      document.css("meta[name=description]").each {|n| @description = n.get_attribute("content").blank? ? "" : n.get_attribute("content").strip}
    end
    @description||=""
  end
  
  def image_sources
    if @images.nil? && document
      @images = []
      document.css("img").each do |n|
        unless n.get_attribute("src").blank?
          img_src = URI.parse(n.get_attribute("src"))
          img_src = @url.merge(img_src).to_s unless img_src.absolute?  
          @images << img_src.to_s
        end
      end
      @images = @images.uniq
    end
    @images
  end
  
    def response
    @response ||= fetch(@url.to_s)
  end
  
  def document
    @document = Nokogiri::HTML(response.plain_body) if @document.nil? && response
    @document
  end
  
  ######
  private
  ######
  
  def fetch(uri_str, limit = 10)
    # You should choose better exception.
    raise ArgumentError, 'HTTP redirect too deep' if limit == 0
    
    url = URI.parse(uri_str)    
    req = Net::HTTP::Get.new(url.request_uri, @headers)
    response = Net::HTTP.start(url.host, url.port) {|http| http.request(req) }
    
    case response
      when Net::HTTPSuccess 
      return handle_special_cases(response, limit)
      #handle redirection
      when Net::HTTPRedirection
      location_uri = URI.parse(response['location'])
      if location_uri.absolute?
        new_uri = location_uri if location_uri.absolute?
      else
        new_uri = @url.clone				
        new_uri.path = location_uri.path[0] == 47 ? location_uri.path : "/#{location_uri.path}"
      end
      return fetch(new_uri.to_s, limit - 1)
    else
      return response.error!
    end
    response
  end
  
  def init_headers(headers)
  	#faking some header so as to act like a normal browser unless otherwise given
  	@headers = {'User-Agent'=>'Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8.1.11) Gecko/20071127 Firefox/2.0.0.11',
                'Accept-Language'=> 'en-us,en;q=0.5',
                'Accept-Charset'=>'ISO-8859-1,utf-8;q=0.7,*;q=0.7'}.merge(headers)
  	#enforece the html or xhtml types only
    @headers['Accept'] = 'text/html,application/xhtml+xml'
  end
  
  def handle_special_cases(response, limit)
    #for handling image search on yahoo and google
    matches = response.plain_body.scan(/<noscript>.*<meta[^>]*HTTP-EQUIV=["']refresh["'][^>]*content=["']\d;url=([^"']+)["'][^>]*>/i)
    return response if matches.length == 0
    url = (matches.collect {|m| m[0]})[0]
    return fetch(url, limit - 1)
  end
  
  def clean_html(html)
    CGI::unescapeHTML(html).gsub(/(\r|\n)/,"").strip if html
  end
end