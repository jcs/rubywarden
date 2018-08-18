require_relative "spec_helper.rb"

describe "identity module" do
  it "should return successful response to account creation" do
    post "/api/accounts/register", {
      :name => nil,
      :email => "nobody@example.com",
      :masterPasswordHash => Bitwarden.hashPassword("asdf",
        "nobody@example.com", User::DEFAULT_KDF_ITERATIONS),
      :masterPasswordHint => nil,
      :key => Bitwarden.makeEncKey(
        Bitwarden.makeKey("adsf", "nobody@example.com",
        User::DEFAULT_KDF_ITERATIONS)
      ),
      :kdf => 0,
      :kdfIterations => User::DEFAULT_KDF_ITERATIONS
    }
    last_response.status.must_equal 200
  end

  it "should not allow duplicate signups" do
    2.times do |x|
      post "/api/accounts/register", {
        :name => nil,
        :email => "nobody2@example.com",
        :masterPasswordHash => Bitwarden.hashPassword("asdf",
          "nobody2@example.com", User::DEFAULT_KDF_ITERATIONS),
        :masterPasswordHint => nil,
        :key => Bitwarden.makeEncKey(
          Bitwarden.makeKey("adsf", "nobody2@example.com",
          User::DEFAULT_KDF_ITERATIONS)
        ),
        :kdf => 0,
        :kdfIterations => User::DEFAULT_KDF_ITERATIONS,
      }
      if x == 0
        last_response.status.must_equal 200
      else
        last_response.status.wont_equal 200
      end
    end
  end

  it "validates required parameters" do
    post "/api/accounts/register", {
      :name => nil,
      :email => "nobody3@example.com",
      :masterPasswordHash => "",
      :masterPasswordHint => nil,
      :key => Bitwarden.makeEncKey(
        Bitwarden.makeKey("adsf", "nobody3@example.com",
        User::DEFAULT_KDF_ITERATIONS)
      ),
      :kdf => 0,
      :kdfIterations => User::DEFAULT_KDF_ITERATIONS,
    }
    last_response.status.wont_equal 200

    post "/api/accounts/register", {
      :name => nil,
      :email => "nobody3@example.com",
      :masterPasswordHash => Bitwarden.hashPassword("asdf",
        "nobody3@example.com", User::DEFAULT_KDF_ITERATIONS),
      :masterPasswordHint => nil,
      :key => "junk",
      :kdf => 0,
      :kdfIterations => User::DEFAULT_KDF_ITERATIONS,
    }
    last_response.status.wont_equal 200
  end

  it "actually creates the user account and allows logging in" do
    post "/api/accounts/register", {
      :name => nil,
      :email => "nobody4@example.com",
      :masterPasswordHash => Bitwarden.hashPassword("asdf",
        "nobody4@example.com", User::DEFAULT_KDF_ITERATIONS),
      :masterPasswordHint => nil,
      :key => Bitwarden.makeEncKey(
        Bitwarden.makeKey("adsf", "nobody4@example.com",
        User::DEFAULT_KDF_ITERATIONS)
      ),
      :kdf => 0,
      :kdfIterations => User::DEFAULT_KDF_ITERATIONS,
    }
    last_response.status.must_equal 200

    (u = User.find_by_email("nobody4@example.com")).wont_be_nil
    u.uuid.wont_be_nil
    u.password_hash.must_equal "PGC1vNJZUL3z5wTKAgpXsODf6KzIPcr0XCzTplceXQU="

    post "/identity/connect/token", {
      :grant_type => "password",
      :username => "nobody4@example.com",
      :password => Bitwarden.hashPassword("asdf", "nobody4@example.com",
        User::DEFAULT_KDF_ITERATIONS),
      :scope => "api offline_access",
      :client_id => "browser",
      :deviceType => 3,
      :deviceIdentifier => SecureRandom.uuid,
      :deviceName => "firefox",
      :devicePushToken => ""
    }

    last_response.status.must_equal 200
    (access_token = last_json_response["access_token"]).wont_be_nil

    get "/api/sync", {}, {
      "HTTP_AUTHORIZATION" => "Bearer #{access_token}",
    }
    last_response.status.must_equal 200
  end

  it "enforces token validity period" do
    post "/api/accounts/register", {
      :name => nil,
      :email => "nobody5@example.com",
      :masterPasswordHash => Bitwarden.hashPassword("asdf",
        "nobody5@example.com", User::DEFAULT_KDF_ITERATIONS),
      :masterPasswordHint => nil,
      :key => Bitwarden.makeEncKey(
        Bitwarden.makeKey("adsf", "nobody5@example.com",
        User::DEFAULT_KDF_ITERATIONS)
      ),
      :kdf => 0,
      :kdfIterations => User::DEFAULT_KDF_ITERATIONS,
    }
    last_response.status.must_equal 200

    post "/identity/connect/token", {
      :grant_type => "password",
      :username => "nobody5@example.com",
      :password => Bitwarden.hashPassword("asdf", "nobody5@example.com",
        User::DEFAULT_KDF_ITERATIONS),
      :scope => "api offline_access",
      :client_id => "browser",
      :deviceType => 3,
      :deviceIdentifier => SecureRandom.uuid,
      :deviceName => "firefox",
      :devicePushToken => ""
    }

    access_token = last_json_response["access_token"]

    get "/api/sync", {}, {
      "HTTP_AUTHORIZATION" => "Bearer #{access_token}",
    }
    last_response.status.must_equal 200

    d = Device.find_by_access_token(access_token)
    d.regenerate_tokens!(1)
    d.save

    get "/api/sync", {}, {
      "HTTP_AUTHORIZATION" => "Bearer #{d.access_token}",
    }
    last_response.status.must_equal 200

    sleep 2

    get "/api/sync", {}, {
      "HTTP_AUTHORIZATION" => "Bearer #{d.access_token}",
    }
    last_response.status.wont_equal 200
  end
end
