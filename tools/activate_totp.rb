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
# Generate a random TOTP secret for the given user, encode it as a URI and
# encode that as a QR code.  Once the user scans the QR code in their
# authenticator app, the current code is entered and if verified, the new
# TOTP secret is saved on the user account.
#

require File.realpath(File.dirname(__FILE__) + "/../lib/rubywarden.rb")
require "getoptlong"
require "rotp"
require "rqrcode"

def usage
  puts "usage: #{$0} -u user@example.com"
  exit 1
end

username = nil

begin
  GetoptLong.new(
    [ "--user", "-u", GetoptLong::REQUIRED_ARGUMENT ],
  ).each do |opt,arg|
    case opt
    when "--user"
      username = arg
    end
  end
rescue GetoptLong::InvalidOption
  usage
end

if !username
  usage
end

u = User.find_by_email(username)
if !u
  raise "can't find existing User record for #{username.inspect}"
end

totp_secret = ROTP::Base32.random_base32
totp = ROTP::TOTP.new(totp_secret, :issuer => "bitwarden-ruby")
totp_url = totp.provisioning_uri(username)

qrcode = RQRCode::QRCode.new(totp_url)
png = qrcode.as_png(:size => 250)

puts "To begin OTP activation for #{username}, open the following URL in a"
puts "web browser and scan the QR code in your OTP authenticator app:"
puts ""
puts "data:image/png;base64," << Base64::strict_encode64(png.to_s)
puts ""

print "Once scanned, enter the current TOTP code from the app: "

tries = 0
while (tries += 1) do
  totp_response = STDIN.gets.strip

  if ROTP::TOTP.new(totp_secret).now == totp_response.to_s
    u.totp_secret = totp_secret

    # force things to login again
    u.security_stamp = nil

    if u.save
      puts "OTP activation complete."
      break
    else
      raise "failed saving"
    end
  elsif tries == 1
    puts "OTP verification failed, please make sure your system time " <<
      "matches the"
    puts "time on the device running the authenticator app:"
    system("date")
    print "Enter the current TOTP code from the app (^C to abort): "
  else
    print "OTP verification failed, please try again (^C to abort): "
  end
end
