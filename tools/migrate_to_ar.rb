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
require File.realpath(File.dirname(__FILE__) + "/../lib/bitwarden_ruby.rb")
ActiveRecord::Base.remove_connection

data_file = "db/dump.yml"

dbconfig = YAML.load(File.read('db/config.yml'))
ActiveRecord::Base.establish_connection dbconfig[environment]

# select only tables for defined models
class YamlDb::SerializationHelper::Dump
  def self.tables
    #ActiveRecord::Base.connection.tables.reject { |table| ['schema_info', 'schema_migrations', 'schema_version'].include?(table) }.sort
    ObjectSpace.each_object(Class).select {|k| k < DBModel}.map {|k| k.table_name }
  end
end

YamlDb::SerializationHelper::Base.new(YamlDb::Helper).dump(data_file)

ActiveRecord::Base.remove_connection

FileUtils.mv dbconfig[environment]["database"], "#{dbconfig[environment]["database"]}.#{Time.now.to_i}"

system "rake db:migrate RACK_ENV=#{environment}"

# add created/updated_at timestamps if missing
class YamlDb::SerializationHelper::Load
  def self.load_records(table, column_names, records)
    if column_names.nil?
      return
    end
    quoted_table_name = YamlDb::SerializationHelper::Utils.quote_table(table)

    if column_names.include? "created_at"
      quoted_column_names = column_names.map { |column| ActiveRecord::Base.connection.quote_column_name(column) }.join(',')
      records.each do |record|
        quoted_values = record.map{|c| ActiveRecord::Base.connection.quote(c)}.join(',')
        ActiveRecord::Base.connection.execute("INSERT INTO #{quoted_table_name} (#{quoted_column_names}) VALUES (#{quoted_values})")
      end
    else
      quoted_column_names = (column_names + ["created_at", "updated_at"]).map { |column| ActiveRecord::Base.connection.quote_column_name(column) }.join(',')
      dummy_timestamp = Time.now.to_i
      records.each do |record|
        quoted_values = (record + [dummy_timestamp, dummy_timestamp]).map{|c| ActiveRecord::Base.connection.quote(c)}.join(',')
        ActiveRecord::Base.connection.execute("INSERT INTO #{quoted_table_name} (#{quoted_column_names}) VALUES (#{quoted_values})")
      end
    end
  end
end

ActiveRecord::Base.establish_connection dbconfig[environment]
YamlDb::SerializationHelper::Base.new(YamlDb::Helper).load(data_file)
FileUtils.rm data_file

# reset created_at / updated_at from seconds since epoch to actual datetime for ar magic
DBModel.record_timestamps = false
ObjectSpace.each_object(Class).select {|k| k < DBModel}.each do |k|
  k.all.each do |i|
    i.update created_at: Time.at(i.created_at), updated_at: Time.at(i.updated_at)
  end
end
DBModel.record_timestamps = true