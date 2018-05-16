source "https://rubygems.org"

ruby ">= 2.2.8", "< 2.5.0"

gem "sinatra", "~> 2.0.1"
gem "sinatra-contrib", "~> 2.0.1"
gem "unicorn"
gem "json"

gem "pbkdf2-ruby"
gem "rotp"
gem "jwt"

gem "sqlite3"

# for tools/activate_totp.rb
gem "rqrcode"

# for testing
gem "rake"
gem "minitest"
gem "rack-test", "~> 0.8"

group :keepass, :optional => true do
  gem 'rubeepass', '~> 3.0'
end

gem "activerecord", "5.1.5"
gem "standalone_migrations", "~> 5.2.0"
gem "filesize"

group :migrate, optional: true do
  gem 'yaml_db'
end

group :development do
  gem 'shotgun'
  gem 'pry'
end