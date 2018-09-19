# see https://github.com/jcs/rubywarden/blob/master/AR-MIGRATE.md

require "fileutils"
require "getoptlong"
require "tempfile"
require "yaml_db"

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

require File.realpath(File.dirname(__FILE__) + "/../lib/rubywarden.rb")

ActiveRecord::Base.remove_connection

dbconfig = YAML.load(File.read(File.realpath(__dir__ + "/../db/config.yml")))

# if a file exists at the new path, some kind of migration has already been
# done so bail out
newdb = dbconfig[environment]["database"]
if File.exists?(newdb)
  raise "a file already exists at #{newdb}, has a migration already taken place?"
end

olddb = File.realpath(__dir__ + "/../db/production.sqlite3")
if !olddb || !File.exists?(olddb)
  raise "no file at #{olddb} to migrate"
end

# point a temporary config at the old db path so we can dump it
tmpconfig = dbconfig[environment].dup
tmpconfig["database"] = olddb
ActiveRecord::Base.establish_connection tmpconfig

# select only tables for defined models
class YamlDb::SerializationHelper::Dump
  def self.tables
    ObjectSpace.each_object(Class).select{|k| k < DBModel}.map{|k| k.table_name }
  end
end

dump_file = Tempfile.new("rubywarden-migrate")

puts "dumping old database to #{dump_file.path}"
YamlDb::SerializationHelper::Base.new(YamlDb::Helper).dump(dump_file.path)
ActiveRecord::Base.remove_connection

puts "creating new database at #{dbconfig[environment]["database"]}"
system("rake", "db:migrate", "RUBYWARDEN_ENV=#{environment}")

puts "importing old database dump"
ActiveRecord::Base.establish_connection dbconfig[environment]
YamlDb::SerializationHelper::Base.new(YamlDb::Helper).load(dump_file.path)

puts "deleting dump file"
dump_file.unlink

# reset created_at / updated_at from seconds since epoch to actual datetime for ar magic
DBModel.record_timestamps = false
ObjectSpace.each_object(Class).select {|k| k < DBModel}.each do |k|
  k.all.each do |i|
    i.update created_at: Time.at(i.created_at), updated_at: Time.at(i.updated_at)
  end
end
DBModel.record_timestamps = true

newdb = File.realpath(__dir__ + "/../" + dbconfig[environment]["database"])
puts "you may wish to delete the old database at #{newdb}"

puts "you may also wish to create a new, unprivileged user to run the"
puts "rubywarden server and own the db/production/ directory"
