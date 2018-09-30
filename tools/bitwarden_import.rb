#!/usr/bin/env ruby
#
# Copyright (c) 2017 joshua stein <jcs@jcs.org>
# bitwarden importer by Ed Marshall <esm@logic.net>
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
# Given a usernamem a bitwarden CSV export file, and a (prompted) master
# password, import each entry into the bitwarden-ruby database.
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

  if row['folder'].present?
    c.folder_uuid = get_or_create_folder_uuid(row['folder'])
  end

  c.favorite = (row['favorite'].to_i == 1)
  c.type = case row['type']
           when 'login' then Cipher::TYPE_LOGIN
           when 'note' then Cipher::TYPE_NOTE
           when 'card' then
             # Note: not currently exported by bitwarden
             Cipher::TYPE_CARD
           else
             raise "#{row['name']} has unknown entry type '#{row['favorite']}'"
           end

  cdata = { 'Name' => encrypt(row['name']) }
  cdata['Notes'] = encrypt(row['notes']) if row['notes'].present?
  if row['fields'].present?
    cdata['Fields'] = []
    row['fields'].split("\n").each do |field|
      # This is best-effort: the export format doesn't escape the separator
      # in the key/value bodies, so field separation is ambiguous. :(
      # It also doesn't include the field type, so we just default to text.
      k, v = field.split(': ', 2)
      cdata['Fields'].push(
        'Type' => 0, # 0 = text, 1 = hidden, 2 = boolean
        'Name' => encrypt(k),
        'Value' => encrypt(v)
      )
    end
  end
  cdata['Uri'] = encrypt(row['login_uri']) if row['login_uri'].present?
  cdata['Username'] = encrypt(row['login_username']) if row['login_username'].present?
  cdata['Password'] = encrypt(row['login_password']) if row['login_password'].present?
  cdata['Totp'] = encrypt(row['login_totp']) if row['login_totp'].present?

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
