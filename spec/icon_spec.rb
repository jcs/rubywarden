require_relative "spec_helper.rb"

describe "icon module" do
  it "should fetch an icon" do
    get "/icons/example.com/icon.png"

    last_response.status.wont_equal 404
  end

  it "should fetch an icon for a long domain" do
    get "/icons/www.internal.corp.example.com/icon.png"

    last_response.status.wont_equal 404
  end
end
