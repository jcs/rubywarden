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

class Attachment < DBModel
  self.table_name = "attachments"
  attr_accessor :context

  before_create :generate_uuid_primary_key
  before_create :generate_url

  belongs_to :cipher, foreign_key: :cipher_uuid, inverse_of: :attachments

  def self.build_from_params(params, context)
    attachment = new filename: params[:filename],
                     size: params[:size],
                     file: params[:file]
    attachment.context = context
    attachment
  end

  def to_hash
    {
      "Id" => self.uuid,
      "Url" => self.url,
      "FileName" => self.filename.to_s,
      "Size" => self.size,
      "SizeName" => human_file_size,
      "Object" => "attachment"
    }
  end

  private

  def generate_url
    self.url = context.url("/attachments/#{self.cipher_uuid}/#{self.id}")
  end

  def human_file_size
    ActiveSupport::NumberHelper.number_to_human_size(self.size)
  end
end
