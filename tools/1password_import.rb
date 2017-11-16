#!/usr/bin/env ruby
#
# Copyright (c) 2017 joshua stein <jcs@jcs.org>
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
# Read a given 1Password Interchange Format (1pif) file, ask for the given
# user's master password, then lookup the given user in the bitwarden-ruby
# SQLite database and fetch its key.  Each 1Password password entry is
# encrypted and inserted into the database.
#
# No check is done to eliminate duplicates, so this is best used on a fresh
# bitwarden-ruby installation after creating a new account.
#

require File.realpath(File.dirname(__FILE__) + "/../lib/bitwarden_ruby.rb")
require "getoptlong"

def usage
  puts "usage: #{$0} -f data.1pif -u user@example.com"
  exit 1
end

username = nil
file = nil

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

@master_key = Bitwarden.makeKey(password, @u.email)

def encrypt(str)
  @u.encrypt_data_with_master_password_key(str, @master_key)
end

to_save = {}
skipped = 0

File.read(file).split("\n").each do |line|
  next if line[0] != "{"
  i = JSON.parse(line)

  c = Cipher.new
  c.user_uuid = @u.uuid
  c.type = Cipher::TYPE_LOGIN
  c.favorite = (i["openContents"] && i["openContents"]["faveIndex"])

  cdata = {
    "Name" => encrypt(i["title"].blank? ? "--" : i["title"]),
  }

  if i["createdAt"]
    c.created_at = Time.at(i["createdAt"].to_i)
  end
  if i["updatedAt"]
    c.updated_at = Time.at(i["updatedAt"].to_i)
  end

  case i["typeName"]
  when "passwords.Password"
    if i["location"].present?
      cdata["Uri"] = encrypt(i["location"])
    end

  when "securenotes.SecureNote"
    c.type = Cipher::TYPE_NOTE
    cdata["SecureNote"] = { "Type" => 0 }

  when "wallet.computer.Router"
    cdata["Password"] = encrypt(i["secureContents"]["wireless_password"])

  when "wallet.financial.CreditCard"
    c.type = Cipher::TYPE_CARD

    if i["secureContents"]["cardholder"].present?
      cdata["CardholderName"] = encrypt(i["secureContents"]["cardholder"])
    end
    if i["secureContents"]["cardholder"].present?
      cdata["Brand"] = encrypt(i["secureContents"]["type"])
    end
    if i["secureContents"]["ccnum"].present?
      cdata["Number"] = encrypt(i["secureContents"]["ccnum"])
    end
    if i["secureContents"]["expiry_mm"].present?
      cdata["ExpMonth"] = encrypt(i["secureContents"]["expiry_mm"])
    end
    if i["secureContents"]["expiry_yy"].present?
      cdata["ExpYear"] = encrypt(i["secureContents"]["expiry_yy"])
    end
    if i["secureContents"]["cvv"].present?
      cdata["Code"] = encrypt(i["secureContents"]["cvv"])
    end

  when "webforms.WebForm"
    if i["location"].present?
      cdata["Uri"] = encrypt(i["location"])
    end

  when "identities.Identity",
  "system.folder.Regular",
  "wallet.computer.License"
    puts "skipping #{i["typeName"]} #{i["title"]}"
    skipped += 1
    next

  else
    raise "unimplemented: #{i["typeName"].inspect}"
  end

  puts "converting #{Cipher.type_s(c.type)} #{i["title"]}... "

  if i["secureContents"]
    if i["secureContents"]["notesPlain"].present?
      cdata["Notes"] = encrypt(i["secureContents"]["notesPlain"])
    end

    if i["secureContents"]["password"].present?
      cdata["Password"] = encrypt(i["secureContents"]["password"])
    end

    if i["secureContents"]["fields"]
      cdata["Fields"] = []

      i["secureContents"]["fields"].each do |field|
        case field["designation"]
        when "username"
          if c.type == Cipher::TYPE_LOGIN && cdata["Username"].blank? &&
          field["value"].present?
            cdata["Username"] = encrypt(field["value"])
          end

        when "password"
          if c.type == Cipher::TYPE_LOGIN && cdata["Password"].blank? &&
          field["value"].present?
            cdata["Password"] = encrypt(field["value"])
          end

        else
          if field["name"].present? && field["name"].match(/password/i)
            # ignore this field, as it's probably a duplicate of the password
            # field and will cause the apps to show it in plaintext rather than
            # as a masked password field
            next
          end

          if field["name"].present? && field["value"].present?
            cdata["Fields"].push({
              "Type" => 0, # text
              "Name" => encrypt(field["name"]),
              "Value" => encrypt(field["value"]),
            })
          end
        end
      end
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
      if !c.save
        raise "failed saving #{c.inspect}"
      end

      imp += 1
    end
  end
end

puts "successfully imported #{imp} item#{imp == 1 ? "" : "s"}"
