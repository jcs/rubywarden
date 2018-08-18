require "rake/testtask"

# rake db:create_migration NAME=...
require "sinatra/activerecord/rake"

Rake::TestTask.new do |t|
  t.pattern = "spec/*_spec.rb"
end

namespace :db do
  task :load_config do
    require "./lib/rubywarden.rb"
  end
end
