require 'fileutils'
require 'getoptlong'
require 'json'

def usage
  puts "usage: #{$PROGRAM_NAME} -h http://localhost:4567 [-t v1.26.0]"
  exit 1
end

host = nil
tag = "v1.26.0"
begin
  GetoptLong.new(
    ['--host', '-h', GetoptLong::REQUIRED_ARGUMENT],
    ['--tag', '-t', GetoptLong::OPTIONAL_ARGUMENT]
  ).each do |opt, arg|
    case opt
    when '--host'
      host = arg
    when '--tag'
      tag = arg
    end
  end
rescue GetoptLong::InvalidOption
  usage
end

usage unless host


FileUtils.mkdir_p "tmp"
FileUtils.cd "tmp" do
  unless Dir.exist?("web")
    system "git clone https://github.com/bitwarden/web.git"
  end
  FileUtils.cd "web" do
    system "git reset --hard HEAD"
    system "git fetch && git fetch --tags"
    system "git checkout #{tag}"


    settings = JSON.parse(File.open("settings.json", 'r:bom|utf-8') {|f| f.read })
    settings["appSettings"]["apiUri"] = "#{host}/api"
    settings["appSettings"]["identityUri"] = "#{host}/identity"
    settings["appSettings"]["iconsUri"] = "#{host}/icons"

    File.open "settings.json", "w" do |f|
      f.puts settings.to_json
    end

    package = JSON.parse(File.open("package.json", 'r:bom|utf-8') {|f| f.read })
    package["env"] = "Development"
    File.open "package.json", "w" do |f|
      f.puts package.to_json
    end
    system "npm install"
    system "gulp dist:selfHosted"
    system "cp -r dist/* ../../public"
  end
end
