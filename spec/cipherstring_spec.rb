require_relative "spec_helper.rb"

describe "bitwarden encryption stuff" do
  it "should make a key from a password and salt" do
    b64 = "2K4YP5Om9r5NpA7FCS4vQX5t+IC4hKYdTJN/C20cz9c="

    k = Bitwarden.makeKey("this is a password", "nobody@example.com", 5000)
    Base64.strict_encode64(k).encode("utf-8").must_equal b64

    # make sure key and salt affect it
    k = Bitwarden.makeKey("this is a password", "nobody2@example.com", 5000)
    Base64.strict_encode64(k).encode("utf-8").wont_equal b64

    k = Bitwarden.makeKey("this is A password", "nobody@example.com", 5000)
    Base64.strict_encode64(k).encode("utf-8").wont_equal b64
  end

  it "should make a cipher string from a key" do
    cs = Bitwarden.makeEncKey(
      Bitwarden.makeKey("this is a password", "nobody@example.com", 5000)
    )

    cs.must_match(/^0\.[^|]+|[^|]+$/)
  end

  it "should hash a password" do
    #def hashedPassword(password, salt)
    Bitwarden.hashPassword("secret password", "user@example.com", 5000).
      must_equal "VRlYxg0x41v40mvDNHljqpHcqlIFwQSzegeq+POW1ww="
  end

  it "should parse a cipher string" do
    cs = Bitwarden::CipherString.parse(
      "0.u7ZhBVHP33j7cud6ImWFcw==|WGcrq5rTEMeyYkWywLmxxxSgHTLBOWThuWRD/6gVKj77+Vd09DiZ83oshVS9+gxyJbQmzXWilZnZRD/52tah1X0MWDRTdI5bTnTf8KfvRCQ="
    )

    cs.type.must_equal Bitwarden::CipherString::TYPE_AESCBC256_B64
    cs.iv.must_equal "u7ZhBVHP33j7cud6ImWFcw=="
    cs.ct.must_equal "WGcrq5rTEMeyYkWywLmxxxSgHTLBOWThuWRD/6gVKj77+Vd09DiZ83oshVS9+gxyJbQmzXWilZnZRD/52tah1X0MWDRTdI5bTnTf8KfvRCQ="
    cs.mac.must_be_nil
  end

  it "should parse a type-3 cipher string" do
    cs = Bitwarden::CipherString.parse("2.ftF0nH3fGtuqVckLZuHGjg==|u0VRhH24uUlVlTZd/uD1lA==|XhBhBGe7or/bXzJRFWLUkFYqauUgxksCrRzNmJyigfw=")
    cs.type.must_equal 2
  end

  it "should encrypt and decrypt properly" do
    ik = Bitwarden.makeKey("password", "user@example.com", 5000)
    ek = Bitwarden.makeEncKey(ik)
    k = Bitwarden.decrypt(ek, ik, nil)
    j = Bitwarden.encrypt("hi there", k[0, 32], k[32, 32])

    cs = Bitwarden::CipherString.parse(j)

    ik = Bitwarden.makeKey("password", "user@example.com", 5000)
    Bitwarden.decrypt(cs.to_s, k[0, 32], k[32, 32]).must_equal "hi there"
  end

  it "should test mac equality" do
    Bitwarden.macsEqual("asdfasdfasdf", "hi", "hi").must_equal true
  end
end
