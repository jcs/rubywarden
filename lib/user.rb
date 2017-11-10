class User < DBModel
  set_table_name "users"
  set_table_attrs [ :id, :email, :name, :password_hash, :key, :totp_secret,
    :security_stamp, :culture ]

  def devices
    @devices ||= Device.find_all_by_user_id(self.id).each{|d| d.user = self }
  end

  def has_password_hash?(hash)
    self.password_hash.timingsafe_equal_to(hash)
  end

  def verifies_totp_code?(code)
    ROTP::TOTP.new(self.totp_secret).now == code.to_i
  end
end
