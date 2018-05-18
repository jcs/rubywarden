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
# uses helpers/attachment_helpers
module BitwardenRuby
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
            # https://github.com/bitwarden/core/blob/master/src/Core/Services/Implementations/CipherService.cs#L148
            #   var attachmentId = Utilities.CoreHelpers.SecureRandomString(32, upper: false, special: false);
            # use hex string, to make validation simpler for get case
            id = SecureRandom.hex(32)[0,32]

            File.open attachment_path(id: id, uuid: params[:uuid], app: app), 'wb' do |f|
              f.write(file.read)
            end

            cipher.add_attachment attachment: {
              Id: id,
              Url: attachment_url(uuid: params[:uuid], id: id),
              FileName: filename,
              Size: file.size,
              SizeName: human_file_size(byte_size: file.size),
              Object: "attachment"
            }

            Cipher.transaction do
              if !cipher.save
                return validation_error("error saving")
              end

              cipher.to_hash.to_json
            end
          end

          delete "/ciphers/:uuid/attachment/:attachment_id" do
            delete_attachment uuid: params[:uuid], attachment_id: params[:attachment_id], app: app
          end

          post "/ciphers/:uuid/attachment/:attachment_id/delete" do
            delete_attachment uuid: params[:uuid], attachment_id: params[:attachment_id], app: app
          end
        end # BASE_URL

        app.get "/attachments/:uuid/:attachment_id" do
          unless params[:uuid] =~ /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/
            return validation_error("invalid uuid")
          end
          unless params[:attachment_id] =~ /\A[0-9a-f]{32}\z/
            return validation_error("invalid attachment id")
          end
          path = attachment_path(id: params[:attachment_id], uuid: params[:uuid], app: app)

          if File.exist? path
            send_file path
          else
            halt 404
          end
        end
      end # registered app
    end
  end
end
