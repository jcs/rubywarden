#!/usr/bin/env ruby
#
# Copyright (c) 2018 joshua stein <jcs@jcs.org>
# Keepass importer by Martin Gross <martin@pc-coholic.de>
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
# Read a given Keepass kdbx file, optional keyfile, ask for the given user's
# master password, then lookup the given user in the bitwarden-ruby SQLite
# database and fetch its key. Each Keepass password entry is encrypted and
# inserted into the database.
#
# No check is done to eliminate duplicates, so this is best used on a fresh
# bitwarden-ruby installation after creating a new account.
#

require File.realpath(File.dirname(__FILE__) + "/../lib/rubywarden.rb")
require "getoptlong"
require "rubeepass"

def usage
  puts "usage: #{$0} -f example.kdb [-k keyfile] -u user@example.com"
  exit 1
end

username = nil
file = nil
keyfile = nil
@folders = {}

begin
  GetoptLong.new(
    [ "--file", "-f", GetoptLong::REQUIRED_ARGUMENT ],
    [ "--keyfile", "-k", GetoptLong::OPTIONAL_ARGUMENT ],
    [ "--user", "-u", GetoptLong::REQUIRED_ARGUMENT ],
  ).each do |opt,arg|
    case opt
    when "--file"
      file = arg

    when "--user"
      username = arg

    when "--keyfile"
      keyfile = arg
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

unless @u.has_password_hash?(Bitwarden.hashPassword(password, @u.email,
Bitwarden::KDF::TYPES[@u.kdf_type], @u.kdf_iterations))
  raise "master password does not match stored hash"
end

@master_key = Bitwarden.makeKey(password, @u.email,
  Bitwarden::KDF::TYPES[@u.kdf_type], @u.kdf_iterations)

@u.folders.each do |folder|
  folder_name = @u.decrypt_data_with_master_password_key(folder.name, @master_key)
  @folders[folder_name] = folder.uuid
end

def encrypt(str)
  @u.encrypt_data_with_master_password_key(str, @master_key)
end

def get_or_create_folder_uuid(str)
  return @folders[str] if @folders.key? str

  f = Folder.new
  f.user_uuid = @u.uuid
  f.name = encrypt(str).to_s

  Folder.transaction do
    return validation_error('error creating folder') unless f.save
  end

  @folders[str] = f.uuid
  f.uuid
end

@to_save = {}

print "master password for #{file}: "
system("stty -echo")
keepasspass = STDIN.gets.chomp
system("stty echo")
print "\n"

@keepass = RubeePass.new(file, keepasspass, keyfile).open
@db = @keepass.db

def getEntries(db)
  if db.entries.any?
    db.entries.each do |entry|
      c = Cipher.new
      c.user_uuid = @u.uuid
      c.type = Cipher::TYPE_LOGIN

      cdata = {
        "Name" => encrypt(entry[1].title.blank? ? "--" : entry[1].title),
      }

      puts "converting #{Cipher.type_s(c.type)} #{entry[1].title}... "

      if entry[1].group.path != "/"
          c.folder_uuid = get_or_create_folder_uuid(entry[1].group.path[1..-1])
      end

      cdata['Uri'] = encrypt(entry[1].url) if entry[1].url.present?
      cdata['Username'] = encrypt(entry[1].username) if entry[1].username.present?
      cdata['Password'] = encrypt(entry[1].password) if entry[1].password.present?
      cdata['Notes'] = encrypt(entry[1].notes) if entry[1].notes.present?

      if entry[1].attachments.any?
        puts "This entry has an attachment - but it won't be converted as rubywarden does not support attachments yet."
      end

      c.data = cdata.to_json

      @to_save[c.type] ||= []
      @to_save[c.type].push c

      next
    end
  end
  if db.groups.any?
    db.groups.each do |group|
      getEntries(group[1])
      next
    end
  end
end

@to_save.each do |k,v|
  puts "#{sprintf("% 4d", v.count)} #{Cipher.type_s(k)}" <<
    (v.count == 1 ? "" : "s")
end

puts ""

getEntries(@db)

print "ready to import? [Y/n] "
if STDIN.gets.to_s.match(/n/i)
  exit 1
end

imp = 0
Cipher.transaction do
  @to_save.each do |_, v|
    v.each do |c|
      # TODO: convert data to each field natively
      c.migrate_data!

      imp += 1
    end
  end
end

puts "successfully imported #{imp} item#{imp == 1 ? "" : "s"}"
