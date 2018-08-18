#!/usr/bin/env ruby
#
# Copyright (c) 2017 joshua stein <jcs@jcs.org>
# LastPass importer by Simon Cantem
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#

#
# Read a given LastPass CSV file, ask for the given user's master password,
# then lookup the given user in the bitwarden-ruby SQLite database and 
# fetch its key.  Each LastPass password & secure note entry is encrypted 
# and inserted into the database.
#
# No check is done to eliminate duplicates, so this is best used on a fresh
# bitwarden-ruby installation after creating a new account.
#

require File.realpath(File.dirname(__FILE__) + "/../lib/rubywarden.rb")
require "getoptlong"
require "csv"

def usage
  puts "usage: #{$0} -f data.csv -u user@example.com"
  exit 1
end

username = nil
file = nil
@folders = {} 

begin
  GetoptLong.new(
    [ "--file", "-f", GetoptLong::REQUIRED_ARGUMENT ],
    [ "--user", "-u", GetoptLong::REQUIRED_ARGUMENT ],
  ).each do |opt,arg|
    case opt
    when "--file"
      file = arg

    when "--user"
      username = arg
    end
  end

rescue GetoptLong::InvalidOption
  usage
end

if !file || !username
  usage
end

@u = User.find_by_email(username)
if !@u
  raise "can't find existing User record for #{username.inspect}"
end

print "master password for #{@u.email}: "
system("stty -echo")
password = STDIN.gets.chomp
system("stty echo")
print "\n"

if !@u.has_password_hash?(Bitwarden.hashPassword(password, username))
  raise "master password does not match stored hash"
end

@master_key = Bitwarden.makeKey(password, @u.email, @u.kdf_iterations)

@u.folders.each do |folder|
  folder_name = @u.decrypt_data_with_master_password_key(folder.name, @master_key)
  @folders[folder_name] = folder.uuid
end

def encrypt(str)
  @u.encrypt_data_with_master_password_key(str, @master_key)
end

def get_or_create_folder_uuid(str)
  if @folders.has_key? str
    return @folders[str]
  end

  f = Folder.new
  f.user_uuid = @u.uuid
  f.name = encrypt(str).to_s

  Folder.transaction do
    if !f.save
      return validation_error("error creating folder")
    end
  end
 
  @folders[str] = f.uuid
  return f.uuid
end

to_save = {}
skipped = 0

CSV.foreach(file, headers: true) do |row|
  next if row["name"].blank?

  puts "converting #{row["name"]}..."

  c = Cipher.new
  c.user_uuid = @u.uuid
  c.type = Cipher::TYPE_LOGIN
  c.favorite = (row["fav"].to_i == 1)

  cdata = {
    "Name" => encrypt(row["name"]),
  }

  if !row["grouping"].blank?
    c.folder_uuid = get_or_create_folder_uuid(row["grouping"])
  end

  # http://sn means it's a secure note
  if row["url"] == "http://sn"
    c.type = Cipher::TYPE_NOTE
    cdata["SecureNote"] = { "Type" => 0 }
    if !row["extra"].blank?
      cdata["Notes"] = encrypt(row["extra"])
    end

  else
    if !row["url"].blank?
      cdata["Uri"] = encrypt(row["url"]) 
    end
    if !row["password"].blank?
      cdata["Password"] = encrypt(row["password"])
    end
    if !row["username"].blank?
      cdata["Username"] = encrypt(row["username"])
    end
    if !row["extra"].blank?
      cdata["Notes"] = encrypt(row["extra"])
    end

  end

  c.data = cdata.to_json

  to_save[c.type] ||= []
  to_save[c.type].push c
end

puts ""

to_save.each do |k,v|
  puts "#{sprintf("% 4d", v.count)} #{Cipher.type_s(k)}" <<
    (v.count == 1 ? "" : "s")
end

if skipped > 0
  puts "#{sprintf("% 4d", skipped)} skipped"
end

print "ready to import? [Y/n] "
if STDIN.gets.to_s.match(/n/i)
  exit 1
end

imp = 0
Cipher.transaction do
  to_save.each do |k,v|
    v.each do |c|
      # TODO: convert data to each field natively and call save! on our own
      c.migrate_data!

      imp += 1
    end
  end
end

puts "successfully imported #{imp} item#{imp == 1 ? "" : "s"}"

