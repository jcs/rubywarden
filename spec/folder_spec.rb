require_relative "spec_helper.rb"

@access_token = nil

describe "folder module" do
  before do
    User.all.delete_all

    post "/api/accounts/register", {
      :name => nil,
      :email => "api@example.com",
      :masterPasswordHash => Bitwarden.hashPassword("asdf", "api@example.com",
        User::DEFAULT_KDF_TYPE,
        Bitwarden::KDF::DEFAULT_ITERATIONS[User::DEFAULT_KDF_TYPE]),
      :masterPasswordHint => nil,
      :key => Bitwarden.makeEncKey(
        Bitwarden.makeKey("adsf", "api@example.com", User::DEFAULT_KDF_TYPE,
        Bitwarden::KDF::DEFAULT_ITERATIONS[User::DEFAULT_KDF_TYPE]),
      ),
      :kdf => Bitwarden::KDF::TYPE_IDS[User::DEFAULT_KDF_TYPE],
      :kdfIterations => Bitwarden::KDF::DEFAULT_ITERATIONS[User::DEFAULT_KDF_TYPE],
    }
    if last_response.status != 200
      raise last_response.inspect
    end

    post "/identity/connect/token", {
      :grant_type => "password",
      :username => "api@example.com",
      :password => Bitwarden.hashPassword("asdf", "api@example.com",
        User::DEFAULT_KDF_TYPE,
        Bitwarden::KDF::DEFAULT_ITERATIONS[User::DEFAULT_KDF_TYPE]),
      :scope => "api offline_access",
      :client_id => "browser",
      :deviceType => 3,
      :deviceIdentifier => SecureRandom.uuid,
      :deviceName => "firefox",
      :devicePushToken => ""
    }
    if last_response.status != 200
      raise last_response.inspect
    end

    @access_token = last_json_response["access_token"]
  end

  it "should not allow access with bogus bearer token" do
    post_json "/api/folders", {
      :name => "2.d7MttWzJTSSKx1qXjHUxlQ==|01Ath5UqFZHk7csk5DVtkQ==|EMLoLREgCUP5Cu4HqIhcLqhiZHn+NsUDp8dAg1Xu0Io=",
    }, {
      "HTTP_AUTHORIZATION" => "Bearer #{@access_token.upcase}",
    }

    last_response.status.wont_equal 200
  end

  it "should allow creating, updating, and deleting folders" do
    post_json "/api/folders", {
      :name => "2.d7MttWzJTSSKx1qXjHUxlQ==|01Ath5UqFZHk7csk5DVtkQ==|EMLoLREgCUP5Cu4HqIhcLqhiZHn+NsUDp8dAg1Xu0Io=",
    }, {
      "HTTP_AUTHORIZATION" => "Bearer #{@access_token}",
    }

    last_response.status.must_equal 200
    uuid = last_json_response["Id"]
    uuid.to_s.wont_equal ""

    f = Folder.find_by_uuid(uuid)
    f.wont_be_nil
    f.uuid.must_equal uuid
    f.name.must_equal "2.d7MttWzJTSSKx1qXjHUxlQ==|01Ath5UqFZHk7csk5DVtkQ==|EMLoLREgCUP5Cu4HqIhcLqhiZHn+NsUDp8dAg1Xu0Io="

    # update

    ik = Bitwarden.makeKey("asdf", "api@example.com",
      User::DEFAULT_KDF_TYPE,
      Bitwarden::KDF::DEFAULT_ITERATIONS[User::DEFAULT_KDF_TYPE])
    new_name = Bitwarden.encrypt("some new name", ik).to_s

    put_json "/api/folders/#{uuid}", {
      :name => new_name,
    }, {
      "HTTP_AUTHORIZATION" => "Bearer #{@access_token}",
    }

    last_response.status.must_equal 200
    last_json_response["Id"].to_s.wont_equal ""

    f = Folder.find_by_uuid(uuid)
    f.name.must_equal new_name

    # delete

    delete_json "/api/folders/#{uuid}", {}, {
      "HTTP_AUTHORIZATION" => "Bearer #{@access_token}",
    }
    last_response.status.must_equal 200

    Folder.find_by_uuid(uuid).must_be_nil
  end

  it "should not allow creating, updating, or deleting bogus ciphers" do
    post_json "/api/folders", {
      :name => "junk",
    }, {
      "HTTP_AUTHORIZATION" => "Bearer #{@access_token}",
    }

    last_response.status.wont_equal 200

    # create, then bogus update

    post_json "/api/folders", {
      :name => "2.d7MttWzJTSSKx1qXjHUxlQ==|01Ath5UqFZHk7csk5DVtkQ==|EMLoLREgCUP5Cu4HqIhcLqhiZHn+NsUDp8dAg1Xu0Io=",
    }, {
      "HTTP_AUTHORIZATION" => "Bearer #{@access_token}",
    }

    last_response.status.must_equal 200
    uuid = last_json_response["Id"]

    put_json "/api/folders/#{uuid}", {
      :name => "bogus",
    }, {
      "HTTP_AUTHORIZATION" => "Bearer #{@access_token}",
    }

    last_response.status.wont_equal 200

    # bogus delete

    delete_json "/api/folders/something-bogus", {}, {
      "HTTP_AUTHORIZATION" => "Bearer #{@access_token}",
    }
    last_response.status.wont_equal 200
  end

  it "should show up in sync" do
    n = "2.d7MttWzJTSSKx1qXjHUxlQ==|01Ath5UqFZHk7csk5DVtkQ==|EMLoLREgCUP5Cu4HqIhcLqhiZHn+NsUDp8dAg1Xu0Io="

    post_json "/api/folders", {
      :name => n,
    }, {
      "HTTP_AUTHORIZATION" => "Bearer #{@access_token}",
    }

    last_response.status.must_equal 200
    uuid = last_json_response["Id"]

    get "/api/sync", {}, {
      "HTTP_AUTHORIZATION" => "Bearer #{@access_token}",
    }
    last_response.status.must_equal 200

    js = last_json_response
    f = js["Folders"].select{|tf| tf["Id"] == uuid }.first
    f.wont_be_nil

    f["Name"].must_equal n
  end
end
