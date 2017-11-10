class Device < DBModel
  set_table_name "devices"
  set_table_attrs [ :id, :device_uuid, :user_id, :name, :device_type,
    :device_push_token, :access_token, :refresh_token, :token_expiry ]

  attr_writer :user

  def generate_tokens!
    self.token_expiry = (Time.now + (60 * 60)).to_i
    self.refresh_token = SecureRandom.urlsafe_base64(64)[0, 64]

    # the official clients parse this JWT and checks for the existence of some
    # of these fields
    self.access_token = Bitwarden.jwt_sign({
      :nbf => (Time.now - (60 * 5)).to_i,
      :exp => self.token_expiry.to_i,
      :iss => IDENTITY_BASE_URL,
      :sub => self.device_uuid,
      :premium => true,
      :name => self.user.name,
      :email => self.user.email,
      :sstamp => self.user.security_stamp,
      :device => self.device_uuid,
      :scope => [ "api", "offline_access" ],
      :amr => [ "Application" ],
    })
  end

  def user
    @user ||= User.find_by_id(self.user_id)
  end
end
