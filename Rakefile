require "rake/testtask"
Rake::TestTask.new do |t|
  t.pattern = "spec/*_spec.rb"
end

require 'standalone_migrations'
StandaloneMigrations::Tasks.load_tasks
