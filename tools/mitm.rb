#!/usr/bin/env ruby
#
# Copyright (c) 2017 joshua stein <jcs@jcs.org>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#

#
# A simple proxy intercepting API calls from a Bitwarden client, dumping them
# out, sending them off to the real Bitwarden servers, dumping the response,
# and sending it back to the client
#

require "sinatra"
require "cgi"
require "net/https"

set :bind, "0.0.0.0"

# log full queries, otherwise just pretty-printed request and response data
RAW_QUERIES = false

BASE_URL = "/api"
IDENTITY_BASE_URL = "/identity"
ICONS_URL = "/icons"

def upstream_url_for(url)
  if url.match(/^#{Regexp.escape(IDENTITY_BASE_URL)}/)
    "https://identity.bitwarden.com" + url.gsub(/^#{Regexp.escape(IDENTITY_BASE_URL)}/, "")
  elsif url.match(/^#{Regexp.escape(ICONS_URL)}/)
    "https://icons.bitwarden.com" + url.gsub(/^#{Regexp.escape(ICONS_URL)}/, "")
  else
    "https://api.bitwarden.com" + url.gsub(/^#{Regexp.escape(BASE_URL)}/, "")
  end
end

# hack in a way to get the actual-cased headers
module Net::HTTPHeader
  alias_method :old_add_field, :add_field

  def actual_headers
    @actual_headers
  end

  def add_field(key, val)
    @actual_headers ||= {}
    @actual_headers[key] = val

    old_add_field key, val
  end
end

delete /(.*)/ do
  proxy_to upstream_url_for(request.path_info), :delete
end

get /(.*)/ do
  proxy_to upstream_url_for(request.path_info), :get
end

post /(.*)/ do
  proxy_to upstream_url_for(request.path_info), :post
end

put /(.*)/ do
  proxy_to upstream_url_for(request.path_info), :put
end

def proxy_to(url, method)
  puts "proxying #{method.to_s.upcase} to #{url}"

  uri = URI.parse(url)
  h = Net::HTTP.new(uri.host, uri.port)
  if RAW_QUERIES
    h.set_debug_output STDOUT
  end

  if uri.scheme == "https"
    h.use_ssl = true
  end

  send_headers = {
    "Content-type" => (request.env["CONTENT_TYPE"] || "application/x-www-form-urlencoded"),
    "Host" => uri.host,
    "User-Agent" => request.env["HTTP_USER_AGENT"],
    # disable gzip to make it easier to inspect
    "Accept-Encoding" => "identity",
  }

  if a = request.env["HTTP_AUTHORIZATION"]
    send_headers["Authorization"] = a
  end

  post_data = request.body.read.to_s

  unless RAW_QUERIES
    if send_headers["Content-type"].to_s.match(/\/json/i)
      puts "client JSON request:",
        JSON.pretty_generate(JSON.parse(post_data))
    else
      puts "client request: #{post_data.inspect}"
    end
  end

  res = case method
  when :post
    res = h.post(uri.path, post_data, send_headers)
  when :get
    res = h.get(uri.path, send_headers)
  when :put
    res = h.put(uri.path, post_data, send_headers)
  when :delete
    res = h.delete(uri.path, send_headers)
  else
    raise "unknown method type #{method.inspect}"
  end

  reply_headers = res.actual_headers.reject{|k,v|
    [ "Connection", "Transfer-Encoding" ].include?(k)
  }

  r = [ res.code.to_i, reply_headers, res.body ]

  unless RAW_QUERIES
    if reply_headers["Content-Type"].to_s.match(/\/json/)
      begin
        puts "proxy JSON reponse:",
          JSON.pretty_generate(JSON.parse(res.body))
      rescue JSON::ParserError => e
        puts "failed parsing JSON response: #{e.message}"
        puts "proxy response: #{res.body}"
      end
    elsif reply_headers["Content-Type"].to_s.match(/image\//i)
      puts "(image data of size #{res.body.bytesize} returned)"
    else
      puts "proxy response: #{res.body}"
    end
  end

  r
end
