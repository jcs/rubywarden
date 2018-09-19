ENV["RUBYWARDEN_ENV"] = "test"

require "minitest/autorun"
require "rack/test"

# most tests require this to be on
ALLOW_SIGNUPS = true

require File.realpath(File.dirname(__FILE__) + "/../lib/rubywarden.rb")
require "#{APP_ROOT}/lib/app.rb"

ActiveRecord::Migrator.up "db/migrate"

# in case migrations changed what we're testing
[ User, Cipher, Device, Folder ].each do |c|
  c.send(:reset_column_information)
end

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
  Rubywarden::App
end
