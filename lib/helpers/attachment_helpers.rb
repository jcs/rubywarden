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

module BitwardenRuby
  module AttachmentHelpers
    def attachment_url(uuid:, id:)
      url("/attachments/#{uuid}/#{id}")
    end

    def attachment_path(id:, uuid:, app:)
      base = File.expand_path("data/attachments/#{uuid}/", app.root)
      FileUtils.mkpath(base)
      File.expand_path(id, base)
    end

    def retrieve_cipher(uuid: )
      d = device_from_bearer
      if !d
        halt validation_error("invalid bearer")
      end

      c = nil
      if params[:uuid].blank? ||
      !(c = Cipher.find_by_user_uuid_and_uuid(d.user_uuid, params[:uuid]))
        halt validation_error("invalid cipher")
      end
      return c
    end

    def delete_attachment uuid:, attachment_id:, app:
      cipher = retrieve_cipher uuid: uuid
      unless attachment_id =~ /\A[0-9a-f]{32}\z/
        return validation_error("invalid attachment id")
      end
      cipher.remove_attachment attachment_id: attachment_id
      path = attachment_path(id: attachment_id, uuid: uuid, app: app)
      Cipher.transaction do
        if !cipher.save
          return validation_error("error saving")
        end
        File.delete path if File.exist? path

        ""
      end
    end

    def human_file_size(byte_size:)
      Filesize.from("#{byte_size} b").pretty
    end
  end
end
