require 'helpers'
require 'net/http'
require 'cgi'
require 'nokogiri'

class HTMLPageDataError < StandardError
end

class HTMLPageData
  # Faking Firefox headers for better information
  DefaultHeaders = {'User-Agent'=>'Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8.1.11) Gecko/20071127 Firefox/2.0.0.11',
                    'Accept-Language'=> 'en-us,en;q=0.5',
                    'Accept-Charset'=> 'ISO-8859-1,utf-8;q=0.7,*;q=0.7',
                    'Connection' => 'close'}
  
  ContentLengthLimit =  1048576
  ContentTypes = ['text/html','application/xhtml+xml']

  # Gets the page information
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
  
  def url
    @url
  end
  
  def host
    @url.host
  end
  
  # Gets the page favicon. It tries to get the favicon from its link tag if possible.
  # If not found it assumes a default favicon
  def favicon
    return @favicon if @favicon
    href = document.css("link[rel*=icon]", "link[rel*=ICON]").first
    if href
      @favicon = href.get_attribute('href')
      @favicon = "#{@url.scheme}://#{@url.host}/#{@favicon.gsub(/^\//,'')}" unless @favicon =~ /^#{@url.scheme}/
    else
      @favicon = "#{@url.scheme}://#{@url.host}/favicon.ico"
    end
    @favicon
  end
  
  # Gets the page's title. Meta title has higher priority than the title tag
  def title
    if @title.nil? && document
      document.css("meta[name=title]","title").each {|n| text = n.get_attribute("content").blank? ? clean_text(n.inner_html) : clean_text(n.get_attribute("content")); @title = text unless text.blank?}
    end
    @title||=""
  end
  
  # Gets the page's keywords from the meta keywords tag
  def keywords
    if @keywords.nil? && document
      document.css("meta[name=keywords]").each {|n| @keywords = n.get_attribute("content").blank? ? [] : n.get_attribute("content").split(",").collect {|k|clean_text(k.strip)}}
    end
    @keywords||=[]
  end
  
  # Gets the page's description from the meta description tag
  def description
    if @description.nil? && document
      document.css("meta[name=description]").each {|n| @description = n.get_attribute("content").blank? ? "" : clean_text(n.get_attribute("content").strip)}
    end
    @description||=""
  end
  
  # Gets all images sources
  def image_sources
    if @images.nil? && document
      @images = []
      document.css("img").each do |n|
        unless n.get_attribute("src").blank?
          begin
            img_src = URI.parse(n.get_attribute("src"))
            img_src = @url.merge(img_src).to_s unless img_src.absolute?          
            @images << img_src.to_s
          rescue Exception
          end
        end
      end
      @images = @images.uniq
    end
    @images
  end
  
  def response #:nodoc:
    @response ||= fetch(@url.to_s)
  end
  
  def document #:nodoc:
    if @document.nil? && response
      @document = if document_encoding
                    Nokogiri::HTML(response.body.force_encoding(document_encoding).encode('utf-8'),nil, 'utf-8')
                  else
                    Nokogiri::HTML(response.body)
                  end
    end
    @document
  end
  
  def document_encoding #:nodoc:
    return @document_encoding if @document_encoding
    response.type_params.each_pair do |k,v|
      @document_encoding = v.upcase if k =~ /charset/i
    end
    unless @document_encoding
      @document_encoding = response.body =~ /<meta[^>]*HTTP-EQUIV=["']Content-Type["'][^>]*content=["'](.*)["']/i && $1 =~ /charset=(.+)/i && $1.upcase
    end
    @document_encoding
  end  
  
  #######
  private
  #######
  
  def fetch(uri_str, limit = 10)
    # You should choose better exception.
    raise ArgumentError, 'HTTP redirect too deep' if limit == 0
    
    url = URI.parse(uri_str)
    response = nil
    
    Net::HTTP.new(url.host, url.port).start do |http|
      http.request_get(url.request_uri, @headers) do |res|
        puts res.inspect
        response = res
        if res.is_a?(Net::HTTPSuccess)
          raise HTMLPageDataError.new("Invalid Content-Type #{res['Content-Type']}") if !self.class::ContentTypes.include? res.content_type
          raise HTMLPageDataError.new("Invalid Content-Length") if res['Content-Length'] && res['Content-Length'].to_i > self.class::ContentLengthLimit          
          res.read_body
        end
      end
    end
    
    case response
      when Net::HTTPSuccess            
        return handle_special_cases(response, limit)
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
    end #end of case
  end
  
  def init_headers(headers)
  	#faking some header so as to act like a normal browser unless otherwise given
  	@headers = self.class::DefaultHeaders.merge(headers)
  	#enforece the html or xhtml types only    
    @headers['Accept'] = "text/html,application/xhtml+xml;q=0.9,*/*;q=0.8"
  end
  
  def handle_special_cases(response, limit)
    #for handling image search on yahoo and google
    matches = response.body.scan(/<noscript>.*<meta[^>]*HTTP-EQUIV=["']refresh["'][^>]*content=["']\d;url=([^"']+)["'][^>]*>/i)
    return response if matches.length == 0
    url = (matches.collect {|m| m[0]})[0]
    return fetch(url, limit - 1)
  end
  
  def clean_text(html)
    html ? CGI::unescapeHTML(html).gsub(/(\r|\n)/,"").strip : html
  end
end
