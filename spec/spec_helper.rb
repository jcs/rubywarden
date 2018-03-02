ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"

# clear out test db
if File.exist?(f = File.dirname(__FILE__) + "/../db/test.sqlite3")
  File.unlink(f)
end

# most tests require this to be on
ALLOW_SIGNUPS = true

require File.realpath(File.dirname(__FILE__) + "/../lib/bitwarden_ruby.rb")
require "#{APP_ROOT}/lib/app.rb"

include Rack::Test::Methods

def last_json_response
  JSON.parse(last_response.body)
end

def get_json(path, params = {}, headers = {})
  json_request :get, path, params, headers
end

def post_json(path, params = {}, headers = {})
  json_request :post, path, params, headers
end

def put_json(path, params = {}, headers = {})
  json_request :put, path, params, headers
end

def delete_json(path, params = {}, headers = {})
  json_request :delete, path, params, headers
end

def json_request(verb, path, params = {}, headers = {})
  send verb, path, params.to_json,
    headers.merge({ "CONTENT_TYPE" => "application/json" })
end

def app
  BitwardenRuby::App
end
