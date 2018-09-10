#
# Copyright (c) 2018 joshua stein <jcs@jcs.org>
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
# uses helpers/attachment_helpers
module Rubywarden
  module Routing
    module Attachments
      def self.registered(app)
        app.namespace BASE_URL do
          post "/ciphers/:uuid/attachment" do
            cipher = retrieve_cipher uuid: params[:uuid]

            need_params(:data) do |p|
              return validation_error("#{p} cannot be blank")
            end

            # we have to extract filename from data -> head, since data -> filename is truncated
            filename = nil
            if md = params[:data][:head].match(/filename=\"(\S+)\"\r\nContent-Type/)
              filename = md[1]
            else
              return validation_error("filename cannot be blank")
            end

            file = params[:data][:tempfile]
            attachment_params = { filename: filename,
                                  size: file.size,
                                  file: file.read }
            attachment = cipher.attachments.build_from_params(attachment_params, self)

            Attachment.transaction do
              if !attachment.save
                return validation_error("error saving")
              end

              cipher.to_hash.to_json
            end
          end

          delete "/ciphers/:uuid/attachment/:attachment_id" do
            delete_attachment uuid: params[:uuid], attachment_uuid: params[:attachment_id]
          end

          post "/ciphers/:uuid/attachment/:attachment_id/delete" do
            delete_attachment uuid: params[:uuid], attachment_uuid: params[:attachment_id]
          end
        end # BASE_URL

        app.get "/attachments/:uuid/:attachment_id" do
          a = Attachment.find_by_uuid_and_cipher_uuid(params[:attachment_id], params[:uuid])
          attachment(a.filename)
          response.write(a.file)
        end
      end # registered app
    end
  end
end
