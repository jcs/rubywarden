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

class Device < DBModel
  self.table_name = "devices"
  #set_primary_key "uuid"

  before_create :generate_uuid_primary_key

  belongs_to :user, foreign_key: :user_uuid, inverse_of: :devices

  DEFAULT_TOKEN_VALIDITY = (60 * 60)

  def regenerate_tokens!(validity = DEFAULT_TOKEN_VALIDITY)
    if self.refresh_token.blank?
      self.refresh_token = SecureRandom.urlsafe_base64(64)[0, 64]
    end

    self.token_expires_at = Time.now + validity

    # the official clients parse this JWT and checks for the existence of some
    # of these fields
    self.access_token = Bitwarden::Token.sign({
      :nbf => (Time.now - (60 * 2)).to_i,
      :exp => self.token_expires_at.to_i,
      :iss => IDENTITY_BASE_URL,
      :sub => self.user.uuid,
      :premium => self.user.premium,
      :name => self.user.name,
      :email => self.user.email,
      :email_verified => self.user.email_verified,
      :sstamp => self.user.security_stamp,
      :device => self.uuid,
      :scope => [ "api", "offline_access" ],
      :amr => [ "Application" ],
    })
  end
end
