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
  module Routing
    module Account
      def self.registered(app)
        app.namespace BASE_URL do

          # Used by the web vault to update the private and public keys if the user doesn't have one.
          post "/accounts/keys" do
            d = device_from_bearer
            if !d
              return validation_error("invalid bearer")
            end

            if !params[:encryptedprivatekey].to_s.match(/^2\..+\|.+/)
              return validation_error("Invalid key")
            end

            d.user.private_key = params[:encryptedprivatekey]
            d.user.public_key = params[:publickey]

            {
              "Id" => d.user_uuid,
              "Name" => d.user.name,
              "Email" => d.user.email,
              "EmailVerified" => d.user.email_verified,
              "Premium" => d.user.premium,
              "MasterPasswordHint" => d.user.password_hint,
              "Culture" => d.user.culture,
              "TwoFactorEnabled" => d.user.totp_secret,
              "Key" => d.user.key,
              "PrivateKey" => d.user.private_key,
              "SecurityStamp" => d.user.security_stamp,
              "Organizations" => "[]",
              "Object" => "profile",
           }.to_json
          end

          # Used by the web vault to connect and load the user profile/datas
          get "/accounts/profile" do
            d = device_from_bearer
            if !d
              return validation_error("invalid bearer")
            end

            {
             "Id" => d.user_uuid,
             "Name" => d.user.name,
             "Email" => d.user.email,
             "EmailVerified" => d.user.email_verified,
             "Premium" => d.user.premium,
             "MasterPasswordHint" => d.user.password_hint,
             "Culture" => d.user.culture,
             "TwoFactorEnabled" => d.user.totp_secret,
             "Key" => d.user.key,
             "PrivateKey" => d.user.private_key,
             "SecurityStamp" => d.user.security_stamp,
             "Organizations" => "[]",
             "Object" => "profile",
            }.to_json
          end

          # Used to update masterpassword
          post "/accounts/password" do
            d = device_from_bearer
            if !d
              return validation_error("invalid bearer")
            end

           need_params(:key, :masterpasswordhash, :newmasterpasswordhash) do |p|
             return validation_error("#{p} cannot be blank")
           end

           if !params[:key].to_s.match(/^0\..+\|.+/)
             return validation_error("Invalid key")
           end

           begin
             Bitwarden::CipherString.parse(params[:key])
           rescue Bitwarden::InvalidCipherString
             return validation_error("Invalid key")
           end

           if d.user.has_password_hash?(params[:masterpasswordhash])
              d.user.key=params[:key]
             d.user.password_hash=params[:newmasterpasswordhash]
           else
             return validation_error("Wrong current password")
           end

            User.transaction do
             if !d.user.save
               return validation_error("Unknown error")
             end
           end
           ""
          end

          # Used to update email
          post "/accounts/email-token" do
           validation_error("Not implemented yet")
          end
        end # namespace
      end # registered
    end # Account
  end # Routing
end # BitwardenRuby