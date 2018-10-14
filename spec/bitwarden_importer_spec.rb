require "spec_helper.rb"

describe "bitwarden importer" do
  before do
    @email = "user@example.com"
    @password = "asdf"

    User.all.delete_all

    @master_key = Bitwarden.makeKey(@password, @email,
      User::DEFAULT_KDF_TYPE,
      Bitwarden::KDF::DEFAULT_ITERATIONS[User::DEFAULT_KDF_TYPE])
    @user = Rubywarden::Test::Factory.create_user email: @email, password: @password
  end

  it "imports all expected data" do
    run_command_and_send_password([
      "ruby", __dir__ + "/../tools/bitwarden_import.rb",
      "-f", __dir__ + "/fixtures/bitwarden_export.csv",
      "-u", @email
    ], @password)

    ciphers = @user.ciphers.all

    # a normal login
    c = ciphers.select{|t| decrypt(t.name) == "example website" }.first
    c.wont_be_nil
    c.type.must_equal Cipher::TYPE_LOGIN
    c.folder.must_be_nil
    decrypt(c.login["Username"]).must_equal "user@example.com"
    decrypt(c.login["Password"]).must_equal "p4ssw0rd"
    decrypt(c.login["Uris"].first["Uri"]).
      must_equal "https://login.example.com/"

    # a login in a folder
    c = ciphers.select{|t| decrypt(t.name) == "A login in a folder" }.first
    c.wont_be_nil
    c.type.must_equal Cipher::TYPE_LOGIN
    c.folder.wont_be_nil
    decrypt(c.folder.name).must_equal "My neato folder"
    decrypt(c.login["Username"]).must_equal "user@example.org"
    decrypt(c.login["Password"]).must_equal "a password"
    decrypt(c.login["Uris"].first["Uri"]).
      must_equal "https://something.example.net/"
    decrypt(c.notes).must_equal "This is a note on the item in a folder"

    # secure note
    c = ciphers.select{|t| decrypt(t.name) == "a secure note" }.first
    c.wont_be_nil
    c.type.must_equal Cipher::TYPE_NOTE
    decrypt(c.notes).
      must_equal "This is a secure note, the contents of which are secret."
    decrypt(c.fields[0]["Name"]).must_equal "A custom field, perhaps"
    decrypt(c.fields[0]["Value"]).must_equal "And its value"
  end

private
  def decrypt(data)
    @user.decrypt_data_with_master_password_key(data, @master_key)
  end
end
