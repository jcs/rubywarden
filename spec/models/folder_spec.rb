require "spec_helper.rb"

describe "folders" do
  it "nullifies foreign key in ciphers" do
    user = User.create
    folder = Folder.create
    cipher = Cipher.create folder: folder, user: user
    folder.destroy
    cipher.reload
    cipher.folder_uuid.must_be_nil
  end
end