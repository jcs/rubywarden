require "spec_helper.rb"

@access_token = nil
@user = nil

describe "account api module" do
  before do
    post "/api/accounts/register", {
      :name => nil,
      :email => "api@example.com",
      :masterPasswordHash => Bitwarden.hashPassword("asdf", "api@example.com"),
      :masterPasswordHint => nil,
      :key => Bitwarden.makeEncKey(
        Bitwarden.makeKey("adsf", "api@example.com")
      ),
    }
    @user = User.last

    post "/identity/connect/token", {
      :grant_type => "password",
      :username => "api@example.com",
      :password => Bitwarden.hashPassword("asdf", "api@example.com"),
      :scope => "api offline_access",
      :client_id => "browser",
      :deviceType => 3,
      :deviceIdentifier => SecureRandom.uuid,
      :deviceName => "firefox",
      :devicePushToken => ""
    }

    @access_token = last_json_response["access_token"]
  end

  it "allows retrieving the profile" do
    get_json "/api/accounts/profile", {
      }, {
        "HTTP_AUTHORIZATION" => "Bearer #{@access_token}",
      }
    last_response.status.must_equal 200
    last_json_response.must_equal @user.to_hash
  end

  it "allows updating the profile" do
    post_json "/api/accounts/profile", {
        name: "New Name",
        culture: "en-US",
        masterPasswordHint: "hint"
      }, {
        "HTTP_AUTHORIZATION" => "Bearer #{@access_token}",
      }
    @user.reload
    last_response.status.must_equal 200
    last_json_response.must_equal @user.to_hash
  end
end