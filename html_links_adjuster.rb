require "socket"
require "uri"
require 'net/http'

class HTMLLinksAdjuster
  def initialize
    super
  end

  def adjust_body(html_body)
    timeout(1) do
      begin
        adjust_body_old(html_body)
      rescue Exception => e
        html_body
      end  
    end
  end

  def adjust_body_old(html_body)
    
    y = html_body.gsub(/<a .*?href=".*?".*?>.*?<\/a>|(>| |;)((http|https):\/\/)?[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}(([0-9]{1,5})?\/.*?(<| |&nbsp;))?/) do |html_link|
      link = nil
      domain = nil
      resource = nil
      
      if html_link[0] == '<'[0]
        matched_data = /<a .*?href="(.*?)".*?>(.*?)<\/a>/.match(html_link)

        #Strip the protocol and also any parameters if available to make true check that those links are equal
        tmp1 = matched_data[1].gsub(/^(http|https):\/\//, '')
        tmp1 = tmp1.gsub(/\?.*/, '')
        tmp1 = tmp1.gsub(/\/$/,'')
        tmp2 = matched_data[2].gsub(/^(http|https):\/\//, '')
        tmp2 = tmp2.gsub(/\?.*/, '')
        tmp2 = tmp2.gsub(/\/$/,'')
        
        if tmp1 == tmp2
          link = matched_data[1]
        end
      else
        case html_link[html_link.length-1]
          when 60,32,59
            index_of_last_character = html_link.length-2
          else
            index_of_last_character = html_link.length-1
        end
        
        #to remove the trailing / character
        if html_link[html_link.length-2] == 47
          index_of_last_character = html_link.length-3
        end
        
        link = html_link[1..index_of_last_character]
      end
      
      if link
        domain, resource = parse_url link
        
        page_header = retrieve_page_header(domain, resource)
        favicon_exists = check_favicon_existance(domain)
        
        #puts page_header
        
        if page_header
          if html_link[0] != '<'[0]
            tmp = ""

            case html_link[0]
              when 62
                tmp += '>'
              when 32
                tmp += ' '
              when 59
                tmp += ';'  
            end
            tmp += "<a href=\"#{prepare_link(link)}\" target=\"_blank\">#{page_header}</a>"
            domain = "http://" + domain.gsub("http://","")
            tmp += "<img src=\"" + domain + "/favicon.ico\" class=\"link_image\" />" if favicon_exists
            case html_link[html_link.length-1]
              when 60
                tmp += '<'
              when 32
                tmp += ' '
              when 59
                tmp += '&nbsp;'  
            end
            
            html_link = tmp
          else
            tmp = "<a href=\"#{prepare_link(link)}\" target=\"_blank\">#{page_header}</a>"
            domain = "http://" + domain.gsub("http://","")
            tmp += "<img src=\"" + domain + "/favicon.ico\" class=\"link_image\" />" if favicon_exists
            html_link = tmp
          end
        else
          if html_link[0] != '<'[0]
            tmp = ""

            case html_link[0]
              when 62
                tmp += '>'
              when 32
                tmp += ' '
              when 59
                tmp += ';'  
            end
            tmp += "<a href=\"#{prepare_link(link)}\" target=\"_blank\">#{prepare_link(link)}</a>"
            case html_link[html_link.length-1]
              when 60
                tmp += '<'
              when 32
                tmp += ' '
              when 59
                tmp += '&nbsp;'  
            end
            
            html_link = tmp
          else
            tmp = "<a href=\"#{prepare_link(link)}\" target=\"_blank\">#{prepare_link(link)}</a>"
            html_link = tmp
          end
        end
      else
        tmp = "<a href=\"#{prepare_link(tmp1)}\" target=\"_blank\">#{tmp2}</a>"
        html_link = tmp        
      end
    end
    
    y
  end

  def prepare_request(domain, fetched_url)
    request = "GET #{fetched_url} HTTP/1.1\n"
    request += "Host: #{domain.gsub(/(http|https):\/\//, '')}\n"
    request += "User-Agent: Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8.1.11) Gecko/20071127 Firefox/2.0.0.11\n"
    request += "Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5\n"
    request += "Accept-Language: en-us,en;q=0.5\n"
    request += "Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7\n"
    request += "Keep-Alive: 300\n"
    request += "Connection: keep-alive\n"
    request += "\n"
    
    request
  end

  def follow_url_till_ok(host, fetched_url, required = 'page_header')
    domain = host
    returned_value = nil
    
    begin
      i = 0
      max = 3
      while(i < max)
        tcp_socket = TCPSocket::new(domain, 80)
        
        request = prepare_request(domain, fetched_url)
        tcp_socket.write(request)
        
        response_line = tcp_socket.readline
        #puts response_line
        case response_line.split(' ')[1].to_i
          when 200
            while( (x = tcp_socket.readline).chomp.length != 0 )
            end
            
            if required == 'page_header'
              received_data = ""
              data = ""
              loop do
                received_data = tcp_socket.read(50)
                data += received_data
                returned_value = get_title(data)
                break if received_data.length == 0 || returned_value != nil
              end
            elsif required == 'favicon'
              returned_value = true
            end
            
            break
          when 301,302
            while( (x = tcp_socket.readline).chomp.length != 0 )
              header_details = x.split(':', 2)
              if header_details[0] == "Location"
                header_details[1] = header_details[1].chomp.lstrip
                if header_details[1][0] == '/'[0]
                  fetched_url = header_details[1]
                else
                  parts = /((^(http|https):\/\/)?([a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}))(([0-9]{1,5})?\/.*)?/.match(header_details[1])
                  if parts[4] == nil
                    domain = host
                  else
                    domain = parts[4]
                  end
                  fetched_url = parts[6] if parts[6]
                end
                break
              end
            end
            i += 1
          else
            break
        end
      end
      
      tcp_socket.close
    rescue => e
      puts ">>>>>>>"
      puts e.inspect
      puts ">>>>>>>"
    end
    
    returned_value
  end

  def retrieve_page_header(host, fetched_url)
    return follow_url_till_ok(host, fetched_url, 'page_header')
  end
  
  def check_favicon_existance(host)
    return follow_url_till_ok(host, '/favicon.ico', 'favicon')
  end
  
  def parse_url(url)
    domain = nil
    fetched_url = nil
    begin
      parts = /((^(http|https):\/\/)?([a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}))(([0-9]{1,5})?\/.*)?/.match(url)
      domain = parts[4]
      if parts[6]
        fetched_url = parts[6]
      else
        fetched_url = '/'
      end
    rescue => e
      puts e.inspect
    end
    return domain, fetched_url
  end
  
  def get_response_charset( url )
    begin
      response = follow_HTTP_redirection_HEAD_only( url )
      charset = response.header['content-type'].match(/charset=(.*)/)[1].strip
    rescue
      ""
    end
  end
  
  #-----#
  private
  #-----#
  
  def follow_HTTP_redirection_HEAD_only(url_string, limit = 3)
      # You should choose better exception.
      raise ArgumentError, 'HTTP redirect too deep' if limit == 0

      domain, fetched_url = parse_url url_string
      #response = Net::HTTP.get_response(URI.parse(url_string))
      response = Net::HTTP.new(domain, 80).head(fetched_url)
      case response
      when Net::HTTPSuccess     then response
      when Net::HTTPRedirection then follow_HTTP_redirection(response['location'], limit - 1)
      else
        response.error!
      end
  end
  
  def get_title(data)
    matched_data = /<title>(.*?)<\/title>/m.match(data)
    
    matched_data.nil? ? nil : matched_data[1]
  end
  
  def prepare_link(link)
    if link[0] != 72 && link[0] != 104
      link = "http://" + link
    end
    link
  end
end