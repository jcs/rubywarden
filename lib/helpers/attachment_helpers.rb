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

module Rubywarden
  module AttachmentHelpers
    def retrieve_cipher(uuid: )
      d = device_from_bearer
      if !d
        halt validation_error("invalid bearer")
      end

      c = nil
      if uuid.blank? || !(c = Cipher.find_by_user_uuid_and_uuid(d.user_uuid, uuid))
        halt validation_error("invalid cipher")
      end
      return c
    end

    def delete_attachment uuid:, attachment_uuid:
      cipher = retrieve_cipher uuid: uuid
      cipher.attachments.find(attachment_uuid).destroy
      ""
    end
  end
end