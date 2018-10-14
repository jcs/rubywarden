module Rubywarden
  module Test
    class Factory
      USER_EMAIL = "user@example.com"
      USER_PASSWORD = "p4ssw0rd"

      def self.create_user email: USER_EMAIL, password: USER_PASSWORD
        u = User.new
        u.email = email
        u.kdf_type = Bitwarden::KDF::TYPE_IDS[User::DEFAULT_KDF_TYPE]
        u.kdf_iterations = Bitwarden::KDF::DEFAULT_ITERATIONS[User::DEFAULT_KDF_TYPE]
        u.password_hash = Bitwarden.hashPassword(password, email,
          Bitwarden::KDF::TYPES[u.kdf_type], u.kdf_iterations)
        u.password_hint = "it's like password but not"
        u.key = Bitwarden.makeEncKey(Bitwarden.makeKey(password, email,
          Bitwarden::KDF::TYPES[u.kdf_type], u.kdf_iterations))
        u.save
        u
      end

      def self.login_user email: USER_EMAIL, password: USER_PASSWORD
        post "/identity/connect/token", {
          :grant_type => "password",
          :username => email,
          :password => Bitwarden.hashPassword(password, email,
            User::DEFAULT_KDF_TYPE,
            Bitwarden::KDF::DEFAULT_ITERATIONS[User::DEFAULT_KDF_TYPE]),
          :scope => "api offline_access",
          :client_id => "browser",
          :deviceType => 3,
          :deviceIdentifier => SecureRandom.uuid,
          :deviceName => "firefox",
          :devicePushToken => ""
        }
        last_response.status.must_equal 200

        last_json_response["access_token"]
      end
    end
  end
end
