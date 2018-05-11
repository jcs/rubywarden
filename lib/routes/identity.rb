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
    module Identity
      def self.registered(app)
        app.namespace IDENTITY_BASE_URL do
          # depending on grant_type:
          #  password: login with a username/password, register/update the device
          #  refresh_token: just generate a new access_token
          # respond with an access_token and refresh_token
          post "/connect/token" do
            d = nil

            case params[:grant_type]
            when "refresh_token"
              need_params(:refresh_token) do |p|
                return validation_error("#{p} cannot be blank")
              end

              d = Device.find_by_refresh_token(params[:refresh_token])
              if !d
                return validation_error("Invalid refresh token")
              end

            when "password"
              need_params(
                :client_id,
                :grant_type,
                :password,
                :scope,
                :username
              ) do |p|
                return validation_error("#{p} cannot be blank")
              end

              if params[:scope] != "api offline_access"
                return validation_error("scope not supported")
              end

              u = User.find_by_email(params[:username])
              if !u
                return validation_error("Invalid username")
              end

              if !u.has_password_hash?(params[:password])
                return validation_error("Invalid password")
              end

              if u.two_factor_enabled? &&
              (params[:twofactortoken].blank? ||
              !u.verifies_totp_code?(params[:twofactortoken]))
                return [ 400, {
                  "error" => "invalid_grant",
                  "error_description" => "Two factor required.",
                  "TwoFactorProviders" => [ 0 ], # authenticator
                  "TwoFactorProviders2" => { "0" => nil }
                }.to_json ]
              end

              d = Device.find_by_uuid(params[:deviceidentifier])
              if d && d.user_uuid != u.uuid
                # wat
                d.destroy
                d = nil
              end

              if !d
                d = Device.new
                d.user_uuid = u.uuid
                d.uuid = params[:deviceidentifier]
              end


              unless web_vault_request?
                need_params(
                  :devicename,
                  :deviceidentifier,
                  :devicetype
                  ) do |p|
                  return validation_error("#{p} cannot be blank")
                end
                d.type = params[:devicetype]
                d.name = params[:devicename]
              end
            else
              return validation_error("grant type not supported")
            end

            d.regenerate_tokens!

            User.transaction do
              if !d.save
                return validation_error("Unknown error")
              end

              response = {
                :access_token => d.access_token,
                :expires_in => (d.token_expires_at - Time.now).floor,
                :token_type => "Bearer",
                :refresh_token => d.refresh_token,
                :Key => d.user.key
                # TODO: when to include :privateKey and :TwoFactorToken?
              }
              response[:PrivateKey] = d.user.private_key if web_vault_request?
              response.to_json
            end
          end
        end
      end
    end
  end
end
