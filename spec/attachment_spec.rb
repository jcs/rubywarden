require "spec_helper.rb"

@access_token = nil
@cipher_uuid = nil
@cipher = nil

describe "attachment module" do
  before do
    User.all.delete_all

    Rubywarden::Test::Factory.create_user
    @access_token = Rubywarden::Test::Factory.login_user

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
    @cipher_uuid = last_json_response["Id"]
    @cipher = Cipher.find_by_uuid(@cipher_uuid)
  end


  it "does not allow access with bogus bearer token" do
    post_json "/api/ciphers/#{@cipher_uuid}/attachment", {
      data: ""
    }, {
      "HTTP_AUTHORIZATION" => "Bearer #{@access_token.upcase}",
    }

    last_response.status.wont_equal 200
  end

  it "allows creating, downloading and deleting an attachment" do
    post "/api/ciphers/#{@cipher_uuid}/attachment", {
      data: Rack::Test::UploadedFile.new(StringIO.new("dummy"), original_filename: "test")
    }, {
      "HTTP_AUTHORIZATION" => "Bearer #{@access_token}"
    }
    last_response.status.must_equal 200
    attachment = last_json_response["Attachments"].first

    # downloading
    get attachment["Url"]
    last_response.status.must_equal 200

    # deleting
    delete_json "/api/ciphers/#{@cipher_uuid}/attachment/#{attachment["Id"]}", {}, {
      "HTTP_AUTHORIZATION" => "Bearer #{@access_token}",
    }

    last_response.status.must_equal 200
    Cipher.find_by_uuid(@cipher_uuid).attachments.must_be_empty
    Dir.glob("tmp/spec/data/attachments/#{@cipher_uuid}/*").must_be_empty
  end

  it "deletes attachments when cipher is deleted" do
    post "/api/ciphers/#{@cipher_uuid}/attachment", {
      data: Rack::Test::UploadedFile.new(StringIO.new("dummy"), original_filename: "test")
    }, {
      "HTTP_AUTHORIZATION" => "Bearer #{@access_token}"
    }
    last_response.status.must_equal 200
    delete_json "/api/ciphers/#{@cipher_uuid}", {}, {
      "HTTP_AUTHORIZATION" => "Bearer #{@access_token}",
    }

    Cipher.find_by_uuid(@cipher_uuid).must_be_nil
    Attachment.where(cipher_uuid: @cipher_uuid).must_be_empty
  end
end