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
    module Api
      def self.registered(app)
        app.namespace BASE_URL do
          # create a new user
          post "/accounts/register" do
            content_type :json

            if !ALLOW_SIGNUPS
              return validation_error("Signups are not permitted")
            end

            need_params(:masterpasswordhash) do |p|
              return validation_error("#{p} cannot be blank")
            end

            if !params[:email].to_s.match(/^.+@.+\..+$/)
              return validation_error("Invalid e-mail address")
            end

            if !params[:key].to_s.match(/^0\..+\|.+/)
              return validation_error("Invalid key")
            end

            if web_vault_request? && !params[:keys][:encryptedPrivateKey].to_s.match(/^2\..+\|.+/)
              return validation_error("Invalid key")
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

            equivalent_domains = EquivalentDomain.where(user: d.user).pluck(:domains)

            global_domains = GlobalEquivalentDomain.active_for_user(user: d.user).map do |dom|
              dom.to_hash
            end

            {
              "Profile" => d.user.to_hash,
              "Collections" => [],
              "Folders" => d.user.folders.map{|f| f.to_hash },
              "Ciphers" => d.user.ciphers.map{|c| c.to_hash },
              "Domains" => {
                "EquivalentDomains" => equivalent_domains,
                "GlobalEquivalentDomains" => global_domains,
                "Object" => "domains",
              },
              "Object" => "sync",
            }.to_json
          end

          #
          # ciphers
          #
          get "/ciphers" do
            d = device_from_bearer
            if !d
              return validation_error("invalid bearer")
            end
            {
              "Data" => d.user.ciphers.map{|f| f.to_hash},
              "Object" => "list",
            }.to_json
          end

          get "/ciphers/:uuid" do
            c = nil

            if !(c = Cipher.find_by_uuid(params[:uuid]))
             return validation_error("invalid cipher")
            end
            c.to_hash.merge({
                "Edit" => true,
            }).to_json
          end

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

          # import ciphers using web-vault
          post "/ciphers/import" do
            d = device_from_bearer
            if !d
              return validation_error("invalid bearer")
            end

            #First we create all the folders
            params[:folders].each do |p|
              f = Folder.new
              f.user_uuid = d.user_uuid
              f.update_from_params(p)
              Folder.transaction do
                if !f.save
                  return validation_error("error saving")
                end
              end
            end

            find_folder_uuid = lambda do |i, user_uuid:|
              folder_index = params.dig(:folderrelationships, i, "value")
              if folder_index
                folder_name = params.dig(:folders, folder_index.to_i, "name")
                Folder.find_by_user_uuid_and_name(d.user_uuid, folder_name).uuid
              else
                nil
              end
            end

            # We create each CipherString
            params[:ciphers].each_with_index do |p,i|
              c = Cipher.new
              c.user_uuid = d.user_uuid
              c.update_from_params(p)
              c.folder_uuid = find_folder_uuid.call(i, user_uuid: d.user_uuid)
              Cipher.transaction do
                if !c.save
                  return validation_error("error saving")
                end
              end
            end
            ""
          end

          # deleting multiple ciphers at once
          post "/ciphers/delete" do
            need_params(:ids) do |p|
              return validation_error("#{p} cannot be blank")
            end

            params[:ids].each do |id|
              delete_cipher app: app, uuid: id
            end

            ""
          end

          # moving ciphers to a folder
          post "/ciphers/move" do
            need_params(:ids, :folderid) do |p|
              return validation_error("#{p} cannot be blank")
            end

            d = device_from_bearer
            if !d
              return validation_error("invalid bearer")
            end

            if !Folder.find_by_user_uuid_and_uuid(d.user_uuid, params[:folderid])
              return validation_error("Invalid folder")
            end

            ciphers = params[:ids].map do |uuid|
              c = nil
              if uuid.blank? || !(c = Cipher.find_by_user_uuid_and_uuid(d.user_uuid, uuid))
                return validation_error("invalid cipher")
              end
              c.folder_uuid = params[:folderid]
              c
            end

            Cipher.transaction do
              ciphers.each do |cipher|
                if !cipher.save
                  return "failed updating folder"
                end
              end
            end

            ""
          end

          # update a cipher
          put "/ciphers/:uuid" do
            update_cipher
          end

          # update a cipher via web vault
          post "/ciphers/:uuid" do
            update_cipher
          end

          # delete a cipher
          delete "/ciphers/:uuid" do
            delete_cipher app: app, uuid: params[:uuid]
          end

          post "/ciphers/:uuid/delete" do
            delete_cipher app: app, uuid: params[:uuid]
          end

          #
          # folders
          #

          # create a new folder
          # retrieve folder
          get "/folders" do
            d = device_from_bearer
            if !d
              return validation_error("invalid bearer")
            end
            {
              "Data" => d.user.folders.map{|f| f.to_hash},
              "Object" => "list",
            }.to_json
          end

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
            delete_folder
          end

          post "/folders/:uuid/delete" do
            delete_folder
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

          get "/collections" do
            {"Data" => [],"Object" => "list"}.to_json
          end
        end # namespace
      end # registerend
    end # Api
  end # Routing
end # BitwardenRuby
