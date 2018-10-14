require_relative "spec_helper.rb"

@access_token = nil

describe "cipher module" do
  before do
    User.all.delete_all

    Rubywarden::Test::Factory.create_user
    @access_token = Rubywarden::Test::Factory.login_user
  end

  it "should not allow access with bogus bearer token" do
    post_json "/api/ciphers", {
      :type => 1,
      :folderId => nil,
      :organizationId => nil,
      :name => "2.d7MttWzJTSSKx1qXjHUxlQ==|01Ath5UqFZHk7csk5DVtkQ==|EMLoLREgCUP5Cu4HqIhcLqhiZHn+NsUDp8dAg1Xu0Io=",
      :notes => nil,
      :favorite => false,
      :login => {
        :uri => "2.T57BwAuV8ubIn/sZPbQC+A==|EhUSSpJWSzSYOdJ/AQzfXuUXxwzcs/6C4tOXqhWAqcM=|OWV2VIqLfoWPs9DiouXGUOtTEkVeklbtJQHkQFIXkC8=",
        :username => "2.JbFkAEZPnuMm70cdP44wtA==|fsN6nbT+udGmOWv8K4otgw==|JbtwmNQa7/48KszT2hAdxpmJ6DRPZst0EDEZx5GzesI=",
        :password => "2.e83hIsk6IRevSr/H1lvZhg==|48KNkSCoTacopXRmIZsbWg==|CIcWgNbaIN2ix2Fx1Gar6rWQeVeboehp4bioAwngr0o=",
        :totp => nil
      }
    }, {
      "HTTP_AUTHORIZATION" => "Bearer #{@access_token.upcase}",
    }

    last_response.status.wont_equal 200
  end

  it "should allow creating, updating, and deleting ciphers" do
    post_json "/api/ciphers", {
      :type => 1,
      :folderId => nil,
      :organizationId => nil,
      :name => "2.d7MttWzJTSSKx1qXjHUxlQ==|01Ath5UqFZHk7csk5DVtkQ==|EMLoLREgCUP5Cu4HqIhcLqhiZHn+NsUDp8dAg1Xu0Io=",
      :notes => nil,
      :favorite => false,
      :login => {
        :uri => "2.T57BwAuV8ubIn/sZPbQC+A==|EhUSSpJWSzSYOdJ/AQzfXuUXxwzcs/6C4tOXqhWAqcM=|OWV2VIqLfoWPs9DiouXGUOtTEkVeklbtJQHkQFIXkC8=",
        :username => "2.JbFkAEZPnuMm70cdP44wtA==|fsN6nbT+udGmOWv8K4otgw==|JbtwmNQa7/48KszT2hAdxpmJ6DRPZst0EDEZx5GzesI=",
        :password => "2.e83hIsk6IRevSr/H1lvZhg==|48KNkSCoTacopXRmIZsbWg==|CIcWgNbaIN2ix2Fx1Gar6rWQeVeboehp4bioAwngr0o=",
        :totp => nil
      }
    }, {
      "HTTP_AUTHORIZATION" => "Bearer #{@access_token}",
    }

    last_response.status.must_equal 200
    uuid = last_json_response["Id"]
    uuid.to_s.wont_equal ""

    c = Cipher.find_by_uuid(uuid)
    c.wont_be_nil
    c.uuid.must_equal uuid
    c.name.must_equal "2.d7MttWzJTSSKx1qXjHUxlQ==|01Ath5UqFZHk7csk5DVtkQ==|EMLoLREgCUP5Cu4HqIhcLqhiZHn+NsUDp8dAg1Xu0Io="

    # update

    ik = Bitwarden.makeKey("asdf", "api@example.com",
      User::DEFAULT_KDF_TYPE,
      Bitwarden::KDF::DEFAULT_ITERATIONS[User::DEFAULT_KDF_TYPE])
    ek = Bitwarden.makeEncKey(ik)
    k = Bitwarden.decrypt(ek, ik)
    new_name = Bitwarden.encrypt("some new name", k).to_s

    put_json "/api/ciphers/#{uuid}", {
      :type => 1,
      :folderId => nil,
      :organizationId => nil,
      :name => new_name,
      :notes => nil,
      :favorite => false,
      :login => {
        :uri => "2.T57BwAuV8ubIn/sZPbQC+A==|EhUSSpJWSzSYOdJ/AQzfXuUXxwzcs/6C4tOXqhWAqcM=|OWV2VIqLfoWPs9DiouXGUOtTEkVeklbtJQHkQFIXkC8=",
        :username => "2.JbFkAEZPnuMm70cdP44wtA==|fsN6nbT+udGmOWv8K4otgw==|JbtwmNQa7/48KszT2hAdxpmJ6DRPZst0EDEZx5GzesI=",
        :password => "2.e83hIsk6IRevSr/H1lvZhg==|48KNkSCoTacopXRmIZsbWg==|CIcWgNbaIN2ix2Fx1Gar6rWQeVeboehp4bioAwngr0o=",
        :totp => nil
      }
    }, {
      "HTTP_AUTHORIZATION" => "Bearer #{@access_token}",
    }

    last_response.status.must_equal 200
    last_json_response["Id"].to_s.wont_equal ""

    c = Cipher.find_by_uuid(last_json_response["Id"])
    c.name.must_equal new_name

    uuid = c.uuid

    # delete

    delete_json "/api/ciphers/#{uuid}", {}, {
      "HTTP_AUTHORIZATION" => "Bearer #{@access_token}",
    }
    last_response.status.must_equal 200

    Cipher.find_by_uuid(uuid).must_be_nil
  end

  it "should not allow creating, updating, or deleting bogus ciphers" do
    post_json "/api/ciphers", {
      :type => -5,
    }, {
      "HTTP_AUTHORIZATION" => "Bearer #{@access_token}",
    }

    last_response.status.wont_equal 200

    # create, then bogus update

    post_json "/api/ciphers", {
      :type => 1,
      :folderId => nil,
      :organizationId => nil,
      :name => "2.d7MttWzJTSSKx1qXjHUxlQ==|01Ath5UqFZHk7csk5DVtkQ==|EMLoLREgCUP5Cu4HqIhcLqhiZHn+NsUDp8dAg1Xu0Io=",
      :notes => nil,
      :favorite => false,
      :login => {
        :uri => "2.T57BwAuV8ubIn/sZPbQC+A==|EhUSSpJWSzSYOdJ/AQzfXuUXxwzcs/6C4tOXqhWAqcM=|OWV2VIqLfoWPs9DiouXGUOtTEkVeklbtJQHkQFIXkC8=",
        :username => "2.JbFkAEZPnuMm70cdP44wtA==|fsN6nbT+udGmOWv8K4otgw==|JbtwmNQa7/48KszT2hAdxpmJ6DRPZst0EDEZx5GzesI=",
        :password => "2.e83hIsk6IRevSr/H1lvZhg==|48KNkSCoTacopXRmIZsbWg==|CIcWgNbaIN2ix2Fx1Gar6rWQeVeboehp4bioAwngr0o=",
        :totp => nil
      }
    }, {
      "HTTP_AUTHORIZATION" => "Bearer #{@access_token}",
    }

    last_response.status.must_equal 200
    uuid = last_json_response["Id"]

    put_json "/api/ciphers/#{uuid}", {
      :type => -5,
    }, {
      "HTTP_AUTHORIZATION" => "Bearer #{@access_token}",
    }

    last_response.status.wont_equal 200

    # bogus delete

    delete_json "/api/ciphers/something-bogus", {}, {
      "HTTP_AUTHORIZATION" => "Bearer #{@access_token}",
    }
    last_response.status.wont_equal 200
  end

  it "should allow assigning ciphers to valid folders" do
    post_json "/api/ciphers", {
      :type => 1,
      :folderId => nil,
      :organizationId => nil,
      :name => "2.d7MttWzJTSSKx1qXjHUxlQ==|01Ath5UqFZHk7csk5DVtkQ==|EMLoLREgCUP5Cu4HqIhcLqhiZHn+NsUDp8dAg1Xu0Io=",
      :notes => nil,
      :favorite => false,
      :login => {
        :uri => "2.T57BwAuV8ubIn/sZPbQC+A==|EhUSSpJWSzSYOdJ/AQzfXuUXxwzcs/6C4tOXqhWAqcM=|OWV2VIqLfoWPs9DiouXGUOtTEkVeklbtJQHkQFIXkC8=",
        :username => "2.JbFkAEZPnuMm70cdP44wtA==|fsN6nbT+udGmOWv8K4otgw==|JbtwmNQa7/48KszT2hAdxpmJ6DRPZst0EDEZx5GzesI=",
        :password => "2.e83hIsk6IRevSr/H1lvZhg==|48KNkSCoTacopXRmIZsbWg==|CIcWgNbaIN2ix2Fx1Gar6rWQeVeboehp4bioAwngr0o=",
        :totp => nil
      }
    }, {
      "HTTP_AUTHORIZATION" => "Bearer #{@access_token}",
    }

    last_response.status.must_equal 200
    uuid = last_json_response["Id"]

    # create folder

    post_json "/api/folders", {
      :name => "2.tqb+y2z4ChCYHj4romVwGQ==|E8+D7aR5CNnd+jF7fdb9ow==|wELCxyy341G2F+w8bTb87PAUi6sdXeIFTFb4N8tk3E0=",
    }, {
      "HTTP_AUTHORIZATION" => "Bearer #{@access_token}",
    }

    last_response.status.must_equal 200
    folder_uuid = last_json_response["Id"]

    # update to put in valid folder

    put_json "/api/ciphers/#{uuid}", {
      :type => 1,
      :folderId => folder_uuid,
      :organizationId => nil,
      :name => "2.d7MttWzJTSSKx1qXjHUxlQ==|01Ath5UqFZHk7csk5DVtkQ==|EMLoLREgCUP5Cu4HqIhcLqhiZHn+NsUDp8dAg1Xu0Io=",
      :notes => nil,
      :favorite => false,
      :login => {
        :uri => "2.T57BwAuV8ubIn/sZPbQC+A==|EhUSSpJWSzSYOdJ/AQzfXuUXxwzcs/6C4tOXqhWAqcM=|OWV2VIqLfoWPs9DiouXGUOtTEkVeklbtJQHkQFIXkC8=",
        :username => "2.JbFkAEZPnuMm70cdP44wtA==|fsN6nbT+udGmOWv8K4otgw==|JbtwmNQa7/48KszT2hAdxpmJ6DRPZst0EDEZx5GzesI=",
        :password => "2.e83hIsk6IRevSr/H1lvZhg==|48KNkSCoTacopXRmIZsbWg==|CIcWgNbaIN2ix2Fx1Gar6rWQeVeboehp4bioAwngr0o=",
        :totp => nil
      }
    }, {
      "HTTP_AUTHORIZATION" => "Bearer #{@access_token}",
    }

    last_response.status.must_equal 200

    # now assign to bogus folder

    put_json "/api/ciphers/#{uuid}", {
      :type => 1,
      :folderId => folder_uuid.reverse,
      :organizationId => nil,
      :name => "2.d7MttWzJTSSKx1qXjHUxlQ==|01Ath5UqFZHk7csk5DVtkQ==|EMLoLREgCUP5Cu4HqIhcLqhiZHn+NsUDp8dAg1Xu0Io=",
      :notes => nil,
      :favorite => false,
      :login => {
        :uri => "2.T57BwAuV8ubIn/sZPbQC+A==|EhUSSpJWSzSYOdJ/AQzfXuUXxwzcs/6C4tOXqhWAqcM=|OWV2VIqLfoWPs9DiouXGUOtTEkVeklbtJQHkQFIXkC8=",
        :username => "2.JbFkAEZPnuMm70cdP44wtA==|fsN6nbT+udGmOWv8K4otgw==|JbtwmNQa7/48KszT2hAdxpmJ6DRPZst0EDEZx5GzesI=",
        :password => "2.e83hIsk6IRevSr/H1lvZhg==|48KNkSCoTacopXRmIZsbWg==|CIcWgNbaIN2ix2Fx1Gar6rWQeVeboehp4bioAwngr0o=",
        :totp => nil
      }
    }, {
      "HTTP_AUTHORIZATION" => "Bearer #{@access_token}",
    }

    last_response.status.wont_equal 200
  end
end
