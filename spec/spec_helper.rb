ENV["RUBYWARDEN_ENV"] = "test"

# most tests require this to be on
ENV["RUBYWARDEN_ALLOW_SIGNUPS"] = "1"

require "minitest/autorun"
require "rack/test"
require "open3"

require File.realpath(File.dirname(__FILE__) + "/../lib/rubywarden.rb")
require "#{APP_ROOT}/lib/app.rb"

if File.exist?(_f = ActiveRecord::Base.connection_config[:database])
  File.unlink(_f)
end

ActiveRecord::Migration.verbose = false
ActiveRecord::Migrator.up "db/migrate"

# in case migrations changed what we're testing
[ Attachment, User, Cipher, Device, Folder ].each do |c|
  c.send(:reset_column_information)
end

include Rack::Test::Methods

Dir[Rubywarden::App.settings.root + '/spec/support/**/*.rb'].sort.each { |f| require f }
include Rubywarden::Test::RequestHelpers


def app
  Rubywarden::App
end

def run_command_and_send_password(cmd, password)
  Open3.popen3(*cmd) do |i,o,e,t|
    i.puts password
    i.close_write

    files = [ e ]
    while files.any?
      if ready = IO.select([ e ])
        ready[0].each do |f|
          begin
            puts "STDERR: #{f.read_nonblock(1024).inspect}"
          rescue EOFError => e
            files.delete f
          end
        end
      end
    end
  end
end
