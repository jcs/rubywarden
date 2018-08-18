require_relative "spec_helper.rb"

describe "User" do
  USER_EMAIL = "user@example.com"
  USER_PASSWORD = "p4ssw0rd"

  before do
    User.all.each{|u| u.destroy }

    u = User.new
    u.email = USER_EMAIL
    u.kdf_iterations = User::DEFAULT_KDF_ITERATIONS
    u.password_hash = Bitwarden.hashPassword(USER_PASSWORD, USER_EMAIL,
      u.kdf_iterations)
    u.password_hint = "it's like password but not"
    u.key = Bitwarden.makeEncKey(Bitwarden.makeKey(USER_PASSWORD, USER_EMAIL,
      u.kdf_iterations))
    u.save
  end

  it "should compare a user's hash" do
    u = User.find_by_email(USER_EMAIL)
    u.email.must_equal USER_EMAIL
    u.has_password_hash?(
      Bitwarden.hashPassword(USER_PASSWORD, USER_EMAIL,
      User::DEFAULT_KDF_ITERATIONS)).must_equal true

    u.has_password_hash?(
      Bitwarden.hashPassword(USER_PASSWORD, USER_EMAIL + "2",
      User::DEFAULT_KDF_ITERATIONS)).wont_equal true
  end

  it "encrypts and decrypts user's ciphers" do
    u = User.find_by_email(USER_EMAIL)

    mk = Bitwarden.makeKey(USER_PASSWORD, USER_EMAIL,
      User::DEFAULT_KDF_ITERATIONS)

    c = Cipher.new
    c.user_uuid = u.uuid
    c.type = Cipher::TYPE_LOGIN

    cdata = {
      "Name" => u.encrypt_data_with_master_password_key("some name", mk).to_s
    }

    c.data = cdata.to_json
    c.migrate_data!.must_equal true

    c = Cipher.last
    u.decrypt_data_with_master_password_key(c.to_hash["Name"], mk).
      must_equal "some name"
  end

  it "supports changing a master password" do
    u = User.find_by_email(USER_EMAIL)

    mk = Bitwarden.makeKey(USER_PASSWORD, USER_EMAIL,
      User::DEFAULT_KDF_ITERATIONS)

    c = Cipher.new
    c.user_uuid = u.uuid
    c.type = Cipher::TYPE_LOGIN

    cdata = {
      "Name" => u.encrypt_data_with_master_password_key("some name", mk).to_s
    }
    c.data = cdata.to_json
    c.migrate_data!.must_equal true

    u.update_master_password(USER_PASSWORD, USER_PASSWORD + "2")
    u.save.must_equal true

    post "/identity/connect/token", {
      :grant_type => "password",
      :username => USER_EMAIL,
      :password => Bitwarden.hashPassword(USER_PASSWORD + "2", USER_EMAIL,
        User::DEFAULT_KDF_ITERATIONS),
      :scope => "api offline_access",
      :client_id => "browser",
      :deviceType => 3,
      :deviceIdentifier => SecureRandom.uuid,
      :deviceName => "firefox",
      :devicePushToken => ""
    }
    last_response.status.must_equal 200

    mk = Bitwarden.makeKey(USER_PASSWORD + "2", USER_EMAIL,
      User::DEFAULT_KDF_ITERATIONS)

    c = Cipher.find_by_uuid(c.uuid)
    u.decrypt_data_with_master_password_key(c.to_hash["Name"], mk).
      must_equal "some name"
  end
end
