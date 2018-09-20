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

require 'sinatra/activerecord'
require 'sinatra/namespace'

require_relative 'helpers/request_helpers'
require_relative 'helpers/attachment_helpers'

require_relative 'routes/api'
require_relative 'routes/icons'
require_relative 'routes/identity'
require_relative 'routes/attachments'

module Rubywarden
  class App < Sinatra::Base
    register Sinatra::Namespace
    register Sinatra::ActiveRecordExtension

    set :root, File.dirname(__FILE__)

    configure do
      enable :logging
    end

    helpers Rubywarden::RequestHelpers
    helpers Rubywarden::AttachmentHelpers

    before do
      if request.content_type.to_s.match(/\Aapplication\/json(;|\z)/)
        js = request.body.read.to_s
        if !js.strip.blank?
          params.merge!(JSON.parse(js))
        end
      end

      # some bitwarden apps send params with uppercased first letter, some all
      # lowercase.  just standardize on all lowercase.
      params.keys.each do |k|
        params[k.downcase.to_sym] = params.delete(k)
      end

      # we're always going to reply with json
      content_type :json
    end

    register Rubywarden::Routing::Api
    register Rubywarden::Routing::Icons
    register Rubywarden::Routing::Identity
    register Rubywarden::Routing::Attachments
  end
end
