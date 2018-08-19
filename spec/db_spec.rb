require_relative "spec_helper.rb"

@access_token = nil

describe "db module" do
  it "should support finding objects by columns" do
    rand = SecureRandom.hex

    u = User.new
    u.email = "#{rand}@#{rand}.com"
    u.password_hash = Bitwarden.hashPassword("blah", u.email,
      User::DEFAULT_KDF_TYPE,
      Bitwarden::KDF::DEFAULT_ITERATIONS[User::DEFAULT_KDF_TYPE]),
    u.password_hint = nil
    u.key = Bitwarden.makeEncKey(
      Bitwarden.makeKey("blah", u.email, User::DEFAULT_KDF_TYPE,
        Bitwarden::KDF::DEFAULT_ITERATIONS[User::DEFAULT_KDF_TYPE])
    )
    u.culture = "en-US"
    u.save.must_equal true

    uuid = u.uuid

    User.where(email: u.email, culture: "en-US").all.first.uuid.must_equal uuid
    User.find_by(email: u.email, culture: "en-US").uuid.must_equal uuid
    User.find_by(email: u.email, culture: "en-NO").must_be_nil
  end
end
