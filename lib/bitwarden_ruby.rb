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

Encoding.default_internal = Encoding.default_external = Encoding::UTF_8

APP_ROOT = File.realpath(File.dirname(__FILE__) + "/../")

RACK_ENV ||= (ENV["RACK_ENV"] || "development")

require "sinatra"
require "sinatra/namespace"
require "cgi"

require "#{APP_ROOT}/lib/bitwarden.rb"
require "#{APP_ROOT}/lib/helper.rb"

require "#{APP_ROOT}/lib/db.rb"
require "#{APP_ROOT}/lib/dbmodel.rb"
require "#{APP_ROOT}/lib/user.rb"
require "#{APP_ROOT}/lib/device.rb"
require "#{APP_ROOT}/lib/domain.rb"
require "#{APP_ROOT}/lib/cipher.rb"
require "#{APP_ROOT}/lib/folder.rb"

BASE_URL ||= "/api"
IDENTITY_BASE_URL ||= "/identity"
ICONS_URL ||= "/icons"

# whether to allow new users
if !defined?(ALLOW_SIGNUPS)
  ALLOW_SIGNUPS = (ENV["ALLOW_SIGNUPS"] || false)
end

# create/load JWT signing keys
Bitwarden::Token.load_keys

# create/update tables
Db.connect("#{APP_ROOT}/db/#{RACK_ENV}.sqlite3")
