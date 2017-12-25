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

require File.dirname(__FILE__) + "/lib/bitwarden_ruby.rb"
require "#{APP_ROOT}/lib/api.rb"

# Parameters to pass to Net::SMTP.start, for sending password hint emails.
# if :tls is true, we'll attempt to set up a TLS connection to the server; if
# :starttls is true, we'll try to use STARTTLS after the connection is
# established.
#
# set smtp: {
#   address: "localhost",
#   port: 25
# }
#
# set :smtp_from, "nobody@localhost"

run Sinatra::Application
