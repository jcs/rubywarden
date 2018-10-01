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

require "jwt"
require "pbkdf2"
require "openssl"

class Bitwarden
  class InvalidCipherString < StandardError; end
  class Bitwarden::KDF
    PBKDF2 = 0

    TYPES = {
      0 => PBKDF2,
    }
    TYPE_IDS = TYPES.invert

    DEFAULT_ITERATIONS = {
      PBKDF2 => 5000,
    }

    ITERATION_RANGES = {
      PBKDF2 => 5000 .. 1_000_000,
    }
  end

  # convenience methods for hashing/encryption/decryption that the apps do,
  # just so we can test against
  class << self
    # stretch a password+salt
    def makeKey(password, salt, kdf_type, kdf_iterations)
      case kdf_type
      when Bitwarden::KDF::PBKDF2
        if !(r = Bitwarden::KDF::ITERATION_RANGES[kdf_type]).include?(kdf_iterations)
          raise "PBKDF2 iterations must be between #{r}"
        end

        PBKDF2.new(:password => password, :salt => salt,
          :iterations => kdf_iterations,
          :hash_function => OpenSSL::Digest::SHA256,
          :key_length => 32).bin_string
      else
        raise "unknown kdf type #{kdf_type.inspect}"
      end
    end

    # encrypt random bytes with a key from makeKey to make a new encryption
    # CipherString
    def makeEncKey(key, algo = CipherString::TYPE_AESCBC256_HMACSHA256_B64)
      pt = OpenSSL::Random.random_bytes(64)
      encrypt(pt, key, algo).to_s
    end

    # base64-encode a wrapped, stretched password+salt for signup/login
    def hashPassword(password, salt, kdf_type, kdf_iterations)
      key = makeKey(password, salt, kdf_type, kdf_iterations)

      case kdf_type
      when Bitwarden::KDF::PBKDF2
        # stretching has already been done in makeKey, only do 1 iteration here
        Base64.strict_encode64(PBKDF2.new(:password => key, :salt => password,
          :iterations => 1, :key_length => 256/8,
          :hash_function => OpenSSL::Digest::SHA256).bin_string)
      else
        raise "unknown kdf type #{kdf_type.inspect}"
      end
    end

    # encrypt+mac a value with a key and mac key and random iv, return a
    # CipherString of it
    def encrypt(pt, key, algo = CipherString::TYPE_AESCBC256_HMACSHA256_B64)
      mac = nil
      macKey = nil

      case algo
      when CipherString::TYPE_AESCBC256_B64
        if key.bytesize != 32
          raise "unhandled key size #{key.bytesize}"
        end

      when CipherString::TYPE_AESCBC256_HMACSHA256_B64
        macKey = nil
        if key.bytesize == 32
          tkey = hkdfStretch(key, "enc", 32)
          macKey = hkdfStretch(key, "mac", 32)
          key = tkey
        elsif key.bytesize == 64
          macKey = key[32, 32]
          key = key[0, 32]
        else
          raise "invalid key size #{key.bytesize}"
        end
      else
        raise "TODO: #{algo}"
      end

      iv = OpenSSL::Random.random_bytes(16)

      cipher = OpenSSL::Cipher.new "AES-256-CBC"
      cipher.encrypt
      cipher.key = key
      cipher.iv = iv
      ct = cipher.update(pt)
      ct << cipher.final

      mac = nil
      if macKey
        mac = OpenSSL::HMAC.digest(OpenSSL::Digest.new("SHA256"), macKey,
          iv + ct)
      end

      CipherString.new(
        mac ? CipherString::TYPE_AESCBC256_HMACSHA256_B64 :
          CipherString::TYPE_AESCBC256_B64,
        Base64.strict_encode64(iv),
        Base64.strict_encode64(ct),
        mac ? Base64.strict_encode64(mac) : nil,
      )
    end

    # compare two hmacs, with double hmac verification
    # https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2011/february/double-hmac-verification/
    def macsEqual(macKey, mac1, mac2)
      hmac1 = OpenSSL::HMAC.digest(OpenSSL::Digest.new("SHA256"), macKey, mac1)
      hmac2 = OpenSSL::HMAC.digest(OpenSSL::Digest.new("SHA256"), macKey, mac2)
      return hmac1 == hmac2
    end

    # decrypt a CipherString and return plaintext
    def decrypt(cs, key)
      if !cs.is_a?(CipherString)
        cs = CipherString.parse(cs)
      end

      iv = Base64.decode64(cs.iv)
      ct = Base64.decode64(cs.ct)
      mac = cs.mac ? Base64.decode64(cs.mac) : nil

      case cs.type
      when CipherString::TYPE_AESCBC256_B64
        cipher = OpenSSL::Cipher.new "AES-256-CBC"
        cipher.decrypt
        cipher.iv = iv
        cipher.key = key
        pt = cipher.update(ct)
        pt << cipher.final
        return pt

      when CipherString::TYPE_AESCBC256_HMACSHA256_B64
        macKey = nil
        if key.bytesize == 32
          tkey = hkdfStretch(key, "enc", 32)
          macKey = hkdfStretch(key, "mac", 32)
          key = tkey
        elsif key.bytesize == 64
          macKey = key[32, 32]
          key = key[0, 32]
        else
          raise "invalid key size #{key.bytesize}"
        end

        cmac = OpenSSL::HMAC.digest(OpenSSL::Digest.new("SHA256"),
          macKey, iv + ct)
        if !self.macsEqual(macKey, mac, cmac)
          raise "invalid mac #{mac.inspect} != #{cmac.inspect}"
        end

        cipher = OpenSSL::Cipher.new "AES-256-CBC"
        cipher.decrypt
        cipher.iv = iv
        cipher.key = key
        pt = cipher.update(ct)
        pt << cipher.final
        return pt

      else
        raise "TODO implement #{c.type}"
      end
    end

    def hkdfStretch(prk, info, size)
      hashlen = 32
      prev = []
      okm = []
      n = (size / hashlen.to_f).ceil
      n.times do |x|
        t = []
        t += prev
        t += info.split("").map{|c| c.ord }
        t += [ (x + 1) ]
        hmac = OpenSSL::HMAC.digest(OpenSSL::Digest.new("SHA256"), prk,
          t.map{|c| c.chr }.join(""))
        prev = hmac.bytes
        okm += hmac.bytes
      end

      if okm.length != size
        raise "invalid hkdf result: #{okm.length} != #{size}"
      end

      okm.map{|c| c.chr }.join("")
    end
  end

  class CipherString
    TYPE_AESCBC256_B64                     = 0
    TYPE_AESCBC128_HMACSHA256_B64          = 1
    TYPE_AESCBC256_HMACSHA256_B64          = 2
    TYPE_RSA2048_OAEPSHA256_B64            = 3
    TYPE_RSA2048_OAEPSHA1_B64              = 4
    TYPE_RSA2048_OAEPSHA256_HMACSHA256_B64 = 5
    TYPE_RSA2048_OAEPSHA1_HMACSHA256_B64   = 6

    attr_reader :type, :iv, :ct, :mac

    def self.parse(str)
      if !(m = str.to_s.match(/\A(\d)\.([^|]+)\|(.+)\z/))
        raise Bitwarden::InvalidCipherString, "invalid CipherString: " <<
          str.inspect
      end

      type = m[1].to_i
      iv = m[2]
      ct, mac = m[3].split("|", 2)
      CipherString.new(type, iv, ct, mac)
    end

    def initialize(type, iv, ct, mac = nil)
      @type = type
      @iv = iv
      @ct = ct
      @mac = mac
    end

    def to_s
      [ self.type.to_s + "." + self.iv, self.ct, self.mac ].
        reject{|p| !p }.
        join("|")
    end
  end

  class Token
    class << self
      KEY = "#{APP_ROOT}/db/#{RUBYWARDEN_ENV}/jwt-rsa.key"

      attr_reader :rsa

      # load or create RSA pair used for JWT signing
      def load_keys
        if File.exist?(KEY)
          @rsa = OpenSSL::PKey::RSA.new File.read(KEY)
        else
          @rsa = OpenSSL::PKey::RSA.generate 2048

          if !Dir.exists?(File.dirname(KEY))
            Dir.mkdir(File.dirname(KEY))
          end
          f = File.new(KEY, File::CREAT|File::TRUNC|File::RDWR, 0600)
          f.write @rsa.to_pem
          f.write @rsa.public_key.to_pem
          f.close
        end
      end

      def sign(payload)
        JWT.encode(payload, @rsa, "RS256")
      end
    end
  end
end
