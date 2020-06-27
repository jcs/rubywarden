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

module Rubywarden
  module Routing
    module Api
      def self.registered(app)
        app.namespace BASE_URL do
          post "/accounts/prelogin" do
            need_params(:email) do |p|
              return validation_error("#{p} cannot be blank")
            end

            kdf_type = User::DEFAULT_KDF_TYPE
            iterations = Bitwarden::KDF::DEFAULT_ITERATIONS[kdf_type]

            if u = User.find_by_email(params[:email])
              iterations = u.kdf_iterations
              kdf_type = Bitwarden::KDF::TYPES[u.kdf_type]
            end

            {
              "Kdf" => Bitwarden::KDF::TYPE_IDS[kdf_type],
              "KdfIterations" => iterations,
            }.to_json
          end

          # create a new user
          post "/accounts/register" do
            content_type :json

            if !ALLOW_SIGNUPS
              return validation_error("Signups are not permitted")
            end

            need_params(:masterpasswordhash, :kdf, :kdfiterations) do |p|
              return validation_error("#{p} cannot be blank")
            end

            if !params[:email].to_s.match(/^.+@.+\..+$/)
              return validation_error("Invalid e-mail address")
            end

            kdf_type = Bitwarden::KDF::TYPES[params[:kdf].to_i]
            if !kdf_type
              return validation_error("invalid kdf type")
            end

            if !Bitwarden::KDF::ITERATION_RANGES[kdf_type].
            include?(params[:kdfiterations].to_i)
              return validation_error("invalid kdf iterations")
            end

            begin
              Bitwarden::CipherString.parse(params[:key])
            rescue Bitwarden::InvalidCipherString
              return validation_error("Invalid key")
            end

            User.transaction do
              params[:email].downcase!

              if User.find_by_email(params[:email])
                return validation_error("E-mail is already in use")
              end

              u = User.new
              u.email = params[:email]
              u.password_hash = params[:masterpasswordhash]
              u.password_hint = params[:masterpasswordhint]
              u.key = params[:key]
              u.kdf_type = Bitwarden::KDF::TYPE_IDS[kdf_type]
              u.kdf_iterations = params[:kdfiterations]

              # is this supposed to come from somewhere?
              u.culture = "en-US"

              # i am a fair and just god
              u.premium = true

              if !u.save
                return validation_error("User save failed")
              end

              ""
            end
          end

          # fetch profile and ciphers
          get "/sync" do
            d = device_from_bearer
            if !d
              return validation_error("invalid bearer")
            end

            {
              "Profile" => d.user.to_hash,
              "Folders" => d.user.folders.map{|f| f.to_hash },
              "Ciphers" => d.user.ciphers.map{|c| c.to_hash },
              "Domains" => {
                "EquivalentDomains" => nil,
                "GlobalEquivalentDomains" => [],
                "Object" => "domains",
              },
              "Object" => "sync",
            }.to_json
          end

          #
          # ciphers
          #

          # create a new cipher
          post "/ciphers" do
            d = device_from_bearer
            if !d
              return validation_error("invalid bearer")
            end

            need_params(:type, :name) do |p|
              return validation_error("#{p} cannot be blank")
            end

            begin
              Bitwarden::CipherString.parse(params[:name])
            rescue Bitwarden::InvalidCipherString
              return validation_error("Invalid name")
            end

            if !params[:folderid].blank?
              if !Folder.find_by_user_uuid_and_uuid(d.user_uuid, params[:folderid])
                return validation_error("Invalid folder")
              end
            end

            c = Cipher.new
            c.user_uuid = d.user_uuid
            c.update_from_params(params)

            Cipher.transaction do
              if !c.save
                return validation_error("error saving")
              end

              c.to_hash.merge({
                "Edit" => true,
              }).to_json
            end
          end

          # update a cipher
          put "/ciphers/:uuid" do
            d = device_from_bearer
            if !d
              return validation_error("invalid bearer")
            end

            c = nil
            if params[:uuid].blank? ||
            !(c = Cipher.find_by_user_uuid_and_uuid(d.user_uuid, params[:uuid]))
              return validation_error("invalid cipher")
            end

            need_params(:type, :name) do |p|
              return validation_error("#{p} cannot be blank")
            end

            begin
              Bitwarden::CipherString.parse(params[:name])
            rescue Bitwarden::InvalidCipherString
              return validation_error("Invalid name")
            end

            if !params[:folderid].blank?
              if !Folder.find_by_user_uuid_and_uuid(d.user_uuid, params[:folderid])
                return validation_error("Invalid folder")
              end
            end

            c.update_from_params(params)

            Cipher.transaction do
              if !c.save
                return validation_error("error saving")
              end

              c.to_hash.merge({
                "Edit" => true,
              }).to_json
            end
          end

          # delete a cipher
          delete "/ciphers/:uuid" do
            delete_cipher app: app, uuid: params[:uuid]
          end

          # delete a cipher (new client)
          put "/ciphers/:uuid/delete" do
            delete_cipher app: app, uuid: params[:uuid]
          end

          #
          # folders
          #

          # create a new folder
          post "/folders" do
            d = device_from_bearer
            if !d
              return validation_error("invalid bearer")
            end

            need_params(:name) do |p|
              return validation_error("#{p} cannot be blank")
            end

            begin
              Bitwarden::CipherString.parse(params[:name])
            rescue
              return validation_error("Invalid name")
            end

            f = Folder.new
            f.user_uuid = d.user_uuid
            f.update_from_params(params)

            Folder.transaction do
              if !f.save
                return validation_error("error saving")
              end

              f.to_hash.to_json
            end
          end

          # rename a folder
          put "/folders/:uuid" do
            d = device_from_bearer
            if !d
              return validation_error("invalid bearer")
            end

            f = nil
            if params[:uuid].blank? ||
            !(f = Folder.find_by_user_uuid_and_uuid(d.user_uuid, params[:uuid]))
              return validation_error("invalid folder")
            end

            need_params(:name) do |p|
              return validation_error("#{p} cannot be blank")
            end

            begin
              Bitwarden::CipherString.parse(params[:name])
            rescue
              return validation_error("Invalid name")
            end

            f.update_from_params(params)

            Folder.transaction do
              if !f.save
                return validation_error("error saving")
              end

              f.to_hash.to_json
            end
          end

          # delete a folder
          delete "/folders/:uuid" do
            d = device_from_bearer
            if !d
              return validation_error("invalid bearer")
            end

            f = nil
            if params[:uuid].blank? ||
            !(f = Folder.find_by_user_uuid_and_uuid(d.user_uuid, params[:uuid]))
              return validation_error("invalid folder")
            end

            f.destroy

            ""
          end

          #
          # device push tokens
          #

          put "/devices/identifier/:uuid/clear-token" do
            # XXX: for some reason, the iOS app doesn't send an Authorization header
            # for this
            d = device_from_bearer
            if !d
              return validation_error("invalid bearer")
            end

            d.push_token = nil

            Device.transaction do
              if !d.save
                return validation_error("error saving")
              end

              ""
            end
          end

          put "/devices/identifier/:uuid/token" do
            d = device_from_bearer
            if !d
              return validation_error("invalid bearer")
            end

            d.push_token = params[:pushtoken]

            Device.transaction do
              if !d.save
                return validation_error("error saving")
              end

              ""
            end
          end
        end
      end
    end
  end
end
