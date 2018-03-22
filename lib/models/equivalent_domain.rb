class EquivalentDomain < DBModel
  set_table_name "equivalent_domains"
  set_primary_key "id"

  attr_writer :user

  def update_domains domains:
    self.domains = domains.to_json
  end

  def user
    @user ||= User.find_by_uuid(self.user_uuid)
  end
end