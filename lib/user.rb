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

require "rotp"

class User < DBModel
  set_table_name "users"
  set_primary_key "uuid"

  def before_save
    if self.security_stamp.blank?
      self.security_stamp = SecureRandom.uuid
    end
    true
  end

  def ciphers
    @ciphers ||= Cipher.find_all_by_user_uuid(self.uuid).
      each{|d| d.user = self }
  end

  def decrypt_data_with_master_password_key(data, mk)
    # self.key is random data encrypted with the key of (password,email), so
    # create that key and decrypt the random data to get the original
    # encryption key, then use that key to decrypt the data
    encKey = Bitwarden.decrypt(self.key, mk[0, 32], mk[32, 32])
    Bitwarden.decrypt(data, encKey[0, 32], encKey[32, 32])
  end

  def devices
    @devices ||= Device.find_all_by_user_uuid(self.uuid).
      each{|d| d.user = self }
  end

  def encrypt_data_with_master_password_key(data, mk)
    # self.key is random data encrypted with the key of (password,email), so
    # create that key and decrypt the random data to get the original
    # encryption key, then use that key to encrypt the data
    encKey = Bitwarden.decrypt(self.key, mk[0, 32], mk[32, 32])
    Bitwarden.encrypt(data, encKey[0, 32], encKey[32, 32])
  end

  def folders
    @folders ||= Folder.find_all_by_user_uuid(self.uuid).
      each{|f| f.user = self }
  end

  def domains
    @domains ||= EquivalentDomain.find_all_by_user_uuid(self.uuid).
      each{|f| f.user = self }
  end

  def has_password_hash?(hash)
    self.password_hash.timingsafe_equal_to(hash)
  end

  # TODO: password_hash=() should update security_stamp when it changes, I
  # think

  def to_hash
    {
      "Id" => self.uuid,
      "Name" => self.name,
      "Email" => self.email,
      "EmailVerified" => self.email_verified,
      "Premium" => self.premium,
      "MasterPasswordHint" => self.password_hint,
      "Culture" => self.culture,
      "TwoFactorEnabled" => self.two_factor_enabled?,
      "Key" => self.key,
      "PrivateKey" => nil,
      "SecurityStamp" => self.security_stamp,
      "Organizations" => [],
      "Object" => "profile"
    }
  end

  def two_factor_enabled?
    self.totp_secret.present?
  end

  def verifies_totp_code?(code)
    ROTP::TOTP.new(self.totp_secret).now == code.to_s
  end
end
