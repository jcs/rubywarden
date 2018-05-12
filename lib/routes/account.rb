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

            User.transaction do
              if !d.user.save
                return validation_error("Unknown error")
              end
            end

            d.user.to_hash.to_json
          end

          # Used by the web vault to connect and load the user profile/data
          get "/accounts/profile" do
            d = device_from_bearer
            if !d
              return validation_error("invalid bearer")
            end

            d.user.to_hash.to_json
          end

          post "/accounts/profile" do
            d = device_from_bearer
            if !d
              return validation_error("invalid bearer")
            end
            need_params(:name, :masterpasswordhint, :culture) do |p|
              return validation_error("#{p} cannot be blank")
            end
            user = d.user
            user.update name: params[:name], password_hint: params[:masterpasswordhint], culture: params[:culture]
            user.to_hash.to_json
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
            return validation_error("not implemented")
            # d = device_from_bearer
            # if !d
            #   return validation_error("invalid bearer")
            # end

            # need_params(:newemail, :masterpasswordhash) do |p|
            #   return validation_error("#{p} cannot be blank")
            # end

            # if d.user.has_password_hash?(params[:masterpasswordhash])
            #   d.user.update email: params[:newemail]
            # else
            #   return validation_error("Wrong password")
            # end
            # ""
          end

          post "/accounts/email" do
            return validation_error("not implemented")
            # d = device_from_bearer
            # if !d
            #   return validation_error("invalid bearer")
            # end
            # need_params(:key, :masterpasswordhash, :newmasterpasswordhash, :newemail, :token) do |p|
            #   return validation_error("#{p} cannot be blank")
            # end

            # if !params[:key].to_s.match(/^0\..+\|.+/)
            #   return validation_error("Invalid key")
            # end

            # begin
            #   Bitwarden::CipherString.parse(params[:key])
            # rescue Bitwarden::InvalidCipherString
            #   return validation_error("Invalid key")
            # end

            # user = d.user
            # if user.has_password_hash?(params[:masterpasswordhash])
            #   user.key = params[:key]
            #   user.password_hash = params[:newmasterpasswordhash]
            #   user.email = params[:email]
            # else
            #   return validation_error("Wrong current password")
            # end

            # if params[:token] != "297150"
            #   return validation_error("Invalid token")
            # end

            # User.transaction do
            #   if !d.user.save
            #     return validation_error("Unknown error")
            #   end
            # end
            # ""
          end

          # Domain rules
          get "/settings/domains" do
            d = device_from_bearer
            if !d
              return validation_error("invalid bearer")
            end
            equivalent_domains = EquivalentDomain.where(user: d.user).pluck(:domains)

            global_domains = GlobalEquivalentDomain.active_for_user(user: d.user).map do |dom|
              dom.to_hash
            end

            {
              "EquivalentDomains" => equivalent_domains,
              "GlobalEquivalentDomains" => global_domains,
              "Object" => "domains"
            }.to_json
          end

          post "/settings/domains" do
            d = device_from_bearer
            if !d
              return validation_error("invalid bearer")
            end

            EquivalentDomain.transaction do
              EquivalentDomain.where(user: d.user).destroy_all

              (params[:equivalentdomains] || []).each do |domains|
                domain = EquivalentDomain.create! user: d.user, domains: domains
              end

              ExcludedGlobalEquivalentDomain.transaction do
                ExcludedGlobalEquivalentDomain.where(user: d.user).each do |dom|
                  dom.destroy
                end

                (params[:excludedglobalequivalentdomains] || []).each do |domain_id|
                   ged = GlobalEquivalentDomain.where(id: domain_id).first
                   if ged
                     ged.exclude_for_user user: d.user
                   end
                end

              end

            end # transaction

            equivalent_domains = EquivalentDomain.where(user: d.user).pluck(:domains)

            global_domains = GlobalEquivalentDomain.active_for_user(user: d.user).map do |dom|
              dom.to_hash
            end

            {
              "EquivalentDomains" => equivalent_domains,
              "GlobalEquivalentDomains" => global_domains,
              "Object" => "domains"
            }.to_json
          end

        end # namespace
      end # registered
    end # Account
  end # Routing
end # BitwardenRuby
