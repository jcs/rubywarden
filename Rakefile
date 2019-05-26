# rake db:create_migration NAME=...
require "sinatra/activerecord/rake"

namespace :db do
  task :load_config do
    require "./lib/rubywarden.rb"
  end
end

require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << "spec"
  t.pattern = "spec/*_spec.rb"
end

task :default => [ :test ]
