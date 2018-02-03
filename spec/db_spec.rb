require "spec_helper.rb"

@access_token = nil

describe "db module" do
  it "should support finding objects by columns" do
    rand = SecureRandom.hex

    u = User.new
    u.email = "#{rand}@#{rand}.com"
    u.password_hash = Bitwarden.hashPassword("blah", u.email)
    u.password_hint = nil
    u.key = Bitwarden.makeEncKey(
      Bitwarden.makeKey("blah", u.email),
    )
    u.culture = "en-US"
    u.save.must_equal true

    uuid = u.uuid

    User.find_all_by_email_and_culture(u.email, "en-US").first.uuid.must_equal uuid
    User.find_by_email_and_culture(u.email, "en-US").uuid.must_equal uuid
    User.find_by_email_and_culture(u.email, "en-NO").must_be_nil
  end
end
