#!/usr/bin/env ruby
#
# Copyright (c) 2017 joshua stein <jcs@jcs.org>
# Chrome importer by Haluk Unal <admin@halukunal.com>
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
# Read a given Chrome CSV file, ask for the given user's master password,
# then lookup the given user in the bitwarden-ruby SQLite database and 
# fetch its key. Import each entry into the bitwarden-ruby database.
# 
# No check is done to eliminate duplicates, so this is best used on a fresh
# bitwarden-ruby installation after creating a new account.
#

require File.realpath(File.dirname(__FILE__) + '/../lib/rubywarden.rb')

require 'csv'
require 'getoptlong'

def usage
  puts "usage: #{$PROGRAM_NAME} -f data.csv -u user@example.com"
  exit 1
end

def encrypt(str)
  @u.encrypt_data_with_master_password_key(str, @master_key).to_s
end

username = nil
file = nil
@folders = {}

begin
  GetoptLong.new(
    ['--file', '-f', GetoptLong::REQUIRED_ARGUMENT],
    ['--user', '-u', GetoptLong::REQUIRED_ARGUMENT]
  ).each do |opt, arg|
    case opt
    when '--file'
      file = arg
    when '--user'
      username = arg
    end
  end
rescue GetoptLong::InvalidOption
  usage
end

usage unless file && username

@u = User.find_by_email(username)
raise "can't find existing User record for #{username.inspect}" unless @u

print "master password for #{@u.email}: "
system('stty -echo') if STDIN.tty?
password = STDIN.gets.chomp
system('stty echo') if STDIN.tty?
puts

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

to_save = {}
skipped = 0

CSV.foreach(file, headers: true) do |row|
  next if row['name'].blank?

  puts "converting #{row['name']}..."

  c = Cipher.new
  c.user_uuid = @u.uuid
  c.type = Cipher::TYPE_LOGIN

  cdata = { 'Name' => encrypt(row['name']) }
  cdata['Uri'] = encrypt(row['url']) if row['url'].present?
  cdata['Username'] = encrypt(row['username']) if row['username'].present?
  cdata['Password'] = encrypt(row['password']) if row['password'].present?

  c.data = cdata.to_json

  to_save[c.type] ||= []
  to_save[c.type].push c
end

puts

to_save.each do |k, v|
  puts "#{format('% 4d', v.count)} #{Cipher.type_s(k)}" <<
       (v.count == 1 ? '' : 's')
end

puts "#{format('% 4d', skipped)} skipped" if skipped > 0

print 'ready to import? [Y/n] '
exit 1 if STDIN.gets =~ /n/i

imp = 0
Cipher.transaction do
  to_save.each_value do |v|
    v.each do |c|
      # TODO: convert data to each field natively and call save! on our own
      c.migrate_data!

      imp += 1
    end
  end
end

puts "successfully imported #{imp} item#{imp == 1 ? '' : 's'}"

# EOF
