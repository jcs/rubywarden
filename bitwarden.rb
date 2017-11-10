#!/usr/bin/env ruby

APP_ROOT = File.dirname(__FILE__)

require "sinatra"
require "sinatra/namespace"
require "cgi"

require "#{APP_ROOT}/lib/bitwarden.rb"
require "#{APP_ROOT}/lib/helper.rb"

require "#{APP_ROOT}/lib/db.rb"
require "#{APP_ROOT}/lib/dbmodel.rb"
require "#{APP_ROOT}/lib/user.rb"
require "#{APP_ROOT}/lib/device.rb"

ALLOW_SIGNUPS = true

BASE_URL = "/api"
IDENTITY_BASE_URL = "/identity"
ICONS_URL = "/icons"

# create/load JWT signing keys
Bitwarden.load_jwt_keys

# create/update tables
Db.connection

before do
  # import JSON params
  if request.request_method.upcase == "POST" &&
  request.content_type.to_s.match(/^application\/json[$;]/)
    params.merge!(JSON.parse(request.body.read))
  end
end

namespace IDENTITY_BASE_URL do
  # login with a username and password, register/update the device, and get an
  # oauth token in response
  post "/connect/token" do
    content_type :json

    need_params(
      :client_id,
      :grant_type,
      :deviceIdentifier,
      :deviceName,
      :deviceType,
      :password,
      :scope,
      :username,
    ) do |p|
      return validation_error("#{p} cannot be blank")
    end

    if params[:grant_type] != "password"
      return validation_error("grant type not supported")
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

    if u.totp_secret.present?
      if params[:twoFactorToken].blank? ||
      !u.verifies_totp_code?(params[:twoFactorToken])
        return [ 400, {
          "error" => "invalid_grant",
          "error_description" => "Two factor required.",
          "TwoFactorProviders" => [ 0 ], # authenticator
          "TwoFactorProviders2" => { "0" => nil }
        }.to_json ]
      end
    end

    d = Device.find_by_device_uuid(params[:deviceIdentifier])
    if d && d.user_id != u.id
      # wat
      d.destroy
      d = nil
    end

    if !d
      d = Device.new
      d.user_id = u.id
      d.device_uuid = params[:deviceIdentifier]
    end

    d.device_type = params[:deviceType]
    d.name = params[:deviceName]
    d.device_push_token = params[:devicePushToken]

    d.generate_tokens!

    User.transaction do
      if d.save
        return tee({
          :access_token => d.access_token,
          :expires_in => (d.token_expiry - Time.now.to_i),
          :token_type => "Bearer",
          :refresh_token => d.refresh_token,
          :Key => d.user.key,
          # TODO: :privateKey and :TwoFactorToken
        }.to_json)
      else
        return validation_error("Unknown error")
      end
    end
  end
end

namespace BASE_URL do
  # create a new user
  post "/accounts/register" do
    content_type :json

    if !ALLOW_SIGNUPS
      return validation_error("Signups are not permitted")
    end

    need_params(:masterPasswordHash) do |p|
      return validation_error("#{p} cannot be blank")
    end

    if !params[:email].to_s.match(/^.+@.+\..+$/)
      return validation_error("Invalid e-mail address")
    end

    if !params[:key].to_s.match(/^0\..+\|.+/)
      return validation_error("Invalid key")
    end

    User.transaction do
      if User.find_by_email(params[:email])
        return validation_error("E-mail is already in use")
      end

      u = User.new
      u.email = params[:email]
      u.password_hash = params[:masterPasswordHash]
      u.key = params[:key]

      if u.save
        return ""
      else
        return validation_error("User save failed")
      end
    end
  end
end
