require "jwt"

class Bitwarden
  class << self
    attr_reader :jwt_rsa

    JWT_KEY = "#{APP_ROOT}/jwt-rsa.key"

    # load or create RSA pair used for JWT signing
    def load_jwt_keys
      if File.exists?(JWT_KEY)
        @jwt_rsa = OpenSSL::PKey::RSA.new File.read(JWT_KEY)
      else
        @jwt_rsa = OpenSSL::PKey::RSA.generate 2048

        f = File.new(JWT_KEY, File::CREAT|File::TRUNC|File::RDWR, 0600)
        f.write @jwt_rsa.to_pem
        f.write @jwt_rsa.public_key.to_pem
        f.close
      end
    end

    def jwt_sign(payload)
      JWT.encode(payload, @jwt_rsa, "RS256")
    end
  end
end
