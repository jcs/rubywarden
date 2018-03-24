# Tool to migrate old. "manually managed" database to active-record + standalone_migrations
## Necessary steps
# 1. Create backup of old database
# 2. Initialize new database with AR
# 3. Migrate data from old to ar-db
# 4. Profit!

require 'getoptlong'

def usage
  puts "usage: #{$PROGRAM_NAME} -e development"
  exit 1
end

environment = nil
begin
  GetoptLong.new(
    ['--environment', '-e', GetoptLong::REQUIRED_ARGUMENT]
  ).each do |opt, arg|
    case opt
    when '--environment'
      environment = arg
    end
  end
rescue GetoptLong::InvalidOption
  usage
end

usage unless environment


require 'yaml_db'
require 'fileutils'

data_file = "db/dump.yml"

dbconfig = YAML.load(File.read('db/config.yml'))
ActiveRecord::Base.establish_connection dbconfig[environment]

# hack to ignore schema_version table
class YamlDb::SerializationHelper::Dump
  def self.tables
    ActiveRecord::Base.connection.tables.reject { |table| ['schema_info', 'schema_migrations', 'schema_version'].include?(table) }.sort
  end
end

YamlDb::SerializationHelper::Base.new(YamlDb::Helper).dump(data_file)

ActiveRecord::Base.remove_connection

FileUtils.mv dbconfig[environment]["database"], "#{dbconfig[environment]["database"]}.#{Time.now.to_i}"

system "rake db:migrate RACK_ENV=#{environment}"

ActiveRecord::Base.establish_connection dbconfig[environment]
YamlDb::SerializationHelper::Base.new(YamlDb::Helper).load(data_file)
FileUtils.rm data_file