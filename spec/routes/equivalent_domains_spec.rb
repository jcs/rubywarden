require "spec_helper.rb"

@access_token = nil

describe "equivalent domains api module" do
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

  it "should allow retrieving the domain rules" do
    get_json "/api/settings/domains", {
    }, {
      "HTTP_AUTHORIZATION" => "Bearer #{@access_token}",
    }
    last_response.status.must_equal 200
    last_json_response.keys.must_include "EquivalentDomains"
    last_json_response.keys.must_include "GlobalEquivalentDomains"
    last_json_response.keys.must_include "Object"
  end

  it "should allow adding and removing domains" do
    post_json "/api/settings/domains", {
      EquivalentDomains: [["amazon.de","amazon.it"]],
      ExcludedGlobalEquivalentDomains: nil
    }, {
      "HTTP_AUTHORIZATION" => "Bearer #{@access_token}",
    }
    last_response.status.must_equal 200
    last_json_response.keys.must_include "EquivalentDomains"
    last_json_response.keys.must_include "GlobalEquivalentDomains"
    last_json_response.keys.must_include "Object"

    last_json_response["EquivalentDomains"].must_include ["amazon.de","amazon.it"]


    post_json "/api/settings/domains", {
      EquivalentDomains: nil,
      ExcludedGlobalEquivalentDomains: nil
    }, {
      "HTTP_AUTHORIZATION" => "Bearer #{@access_token}",
    }
    last_response.status.must_equal 200
    last_json_response["EquivalentDomains"].size.must_equal 0
  end

  it "should allow excluding global domains" do
    ged = GlobalEquivalentDomain.new
    ged.domains = ["test.com", "example.com"].to_json
    ged.save
    ged = GlobalEquivalentDomain.all.first

    post_json "/api/settings/domains", {
      EquivalentDomains: nil,
      ExcludedGlobalEquivalentDomains: [ged.id]
    }, {
      "HTTP_AUTHORIZATION" => "Bearer #{@access_token}",
    }

    last_response.status.must_equal 200
    last_json_response["GlobalEquivalentDomains"].first["Excluded"].must_equal true
  end
end