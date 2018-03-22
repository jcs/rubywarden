require 'fileutils'
require 'getoptlong'
require 'json'

def usage
  puts "usage: #{$PROGRAM_NAME} -h http://localhost:4567"
  exit 1
end

host = nil

begin
  GetoptLong.new(
    ['--host', '-h', GetoptLong::REQUIRED_ARGUMENT]
  ).each do |opt, arg|
    case opt
    when '--host'
      host = arg
    end
  end
rescue GetoptLong::InvalidOption
  usage
end

usage unless host


FileUtils.mkdir_p "tmp"
FileUtils.cd "tmp" do
  if Dir.exists?("web")
    system "git pull origin master"
  else
    system "git clone https://github.com/bitwarden/web.git"
  end
  FileUtils.cd "web" do
    settings = JSON.parse(File.open("settings.json", 'r:bom|utf-8') {|f| f.read })
    settings["appSettings"]["apiUri"] = "#{host}/api"
    settings["appSettings"]["identityUri"] = "#{host}/identity"
    settings["appSettings"]["iconsUri"] = "#{host}/icons"


    File.open "settings.json", "w" do |f|
      f.puts settings.to_json
    end

    package = JSON.parse(File.open("package.json", 'r:bom|utf-8') {|f| f.read })
    package["Env"] = "Development"
    File.open "package.json", "w" do |f|
      f.puts package.to_json
    end
    system "npm install"
    system "gulp dist:selfHosted"
    system "cp -r dist/* ../../public"
  end
end
